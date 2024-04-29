const std = @import("std");
const generateKeypairRunStep = @import("base58/build.zig").generateKeypairRunStep;

const test_paths = [_][]const u8{
    "metaplex/metaplex.zig",
    "sol.zig",
    "spl/spl.zig",
};

pub fn build(b: *std.Build) !void {
    const sol_modules = allSolModules(b, "");

    const test_step = b.step("test", "Run unit tests");
    inline for (test_paths) |path| {
        const unit_tests = b.addTest(.{
            .root_source_file = .{ .path = path },
        });
        inline for (sol_modules) |package| {
            unit_tests.root_module.addImport(package.name, package.module);
        }
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}

pub fn addSolModules(b: *std.Build, program: *std.Build.Step.Compile, comptime base_dir: []const u8) void {
    const sol_modules = allSolModules(b, base_dir);
    inline for (sol_modules) |package| {
        program.root_module.addImport(package.name, package.module);
    }
}

const AddModule = struct {
    name: []const u8,
    module: *std.Build.Module,
};

pub fn allSolModules(b: *std.Build, comptime base_dir: []const u8) [6]AddModule {
    const base58 = .{ .name = "base58", .module = b.createModule(.{
        .root_source_file = .{ .path = base_dir ++ "base58/base58.zig" },
    }) };

    const bincode = .{ .name = "bincode", .module = b.createModule(.{
        .root_source_file = .{ .path = base_dir ++ "bincode/bincode.zig" },
    }) };

    const borsh = .{ .name = "borsh", .module = b.createModule(.{
        .root_source_file = .{ .path = base_dir ++ "borsh/borsh.zig" },
    }) };

    const sol = .{ .name = "sol", .module = b.createModule(.{
        .root_source_file = .{ .path = base_dir ++ "sol.zig" },
    }) };
    sol.module.addImport(base58.name, base58.module);
    sol.module.addImport(bincode.name, bincode.module);

    const spl = .{ .name = "spl", .module = b.createModule(.{
        .root_source_file = .{ .path = base_dir ++ "spl/spl.zig" },
    }) };
    spl.module.addImport(sol.name, sol.module);
    spl.module.addImport(bincode.name, bincode.module);

    const metaplex = .{ .name = "metaplex", .module = b.createModule(.{
        .root_source_file = .{ .path = base_dir ++ "metaplex/metaplex.zig" },
    }) };
    metaplex.module.addImport(sol.name, sol.module);
    metaplex.module.addImport(borsh.name, borsh.module);

    return [_]AddModule{
        base58,
        bincode,
        borsh,
        sol,
        spl,
        metaplex,
    };
}

pub fn buildProgram(b: *std.Build, program: *std.Build.Step.Compile, comptime base_dir: []const u8) !void {
    addSolModules(b, program, base_dir);
    b.installArtifact(program);

    try linkSolanaProgram(b, program);

    const program_name = program.out_filename[0 .. program.out_filename.len - std.fs.path.extension(program.out_filename).len];
    const path = b.fmt("{s}-keypair.json", .{program_name});
    const lib_path = b.getInstallPath(.lib, path);
    const run_step = try generateKeypairRunStep(b, base_dir ++ "base58/", lib_path);
    b.getInstallStep().dependOn(&run_step.step);
}

pub const sbf_target: std.Target.Query = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.featureSet(&.{.solana}),
};

pub const sbfv2_target: std.Target.Query = .{
    .cpu_arch = .sbf,
    .cpu_model = .{
        .explicit = &std.Target.sbf.cpu.sbfv2,
    },
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.cpu.sbfv2.features,
};

pub const bpf_target: std.Target.Query = .{
    .cpu_arch = .bpfel,
    .os_tag = .freestanding,
    .cpu_features_add = std.Target.bpf.featureSet(&.{.solana}),
};

pub fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) !void {
    // TODO: Due to https://github.com/ziglang/zig/issues/18404, this script
    // maps .data into .rodata, which only catches issues at runtime rather than
    // compile-time, if the program tries to use .data
    const linker_script = b.addWriteFile("bpf.ld",
        \\PHDRS
        \\{
        \\text PT_LOAD  ;
        \\rodata PT_LOAD ;
        \\data PT_LOAD ;
        \\dynamic PT_DYNAMIC ;
        \\}
        \\
        \\SECTIONS
        \\{
        \\. = SIZEOF_HEADERS;
        \\.text : { *(.text*) } :text
        \\.rodata : { *(.rodata*) } :rodata
        \\.rodata : { *(.data*) } :data
        \\.data.rel.ro : { *(.data.rel.ro*) } :rodata
        \\.dynamic : { *(.dynamic) } :dynamic
        \\.dynsym : { *(.dynsym) } :data
        \\.rel.dyn : { *(.rel.dyn) } :data
        \\/DISCARD/ : {
        \\*(.eh_frame*)
        \\*(.gnu.hash*)
        \\*(.hash*)
        \\}
        \\}
    );

    lib.step.dependOn(&linker_script.step);

    lib.setLinkerScript(linker_script.files.items[0].getPath());
    lib.stack_size = 4096;
    lib.link_z_notext = true;
    lib.root_module.pic = true;
    lib.root_module.strip = true;
    lib.entry = .{ .symbol_name = "entrypoint" };
}
