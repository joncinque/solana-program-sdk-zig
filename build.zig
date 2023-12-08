const std = @import("std");

const test_paths = [_][]const u8{
    "metaplex/metaplex.zig",
    "sol.zig",
    "spl/spl.zig",
};

pub fn build(b: *std.build.Builder) !void {
    const sol_modules = allSolModules(b, "");

    const test_step = b.step("test", "Run unit tests");
    inline for (test_paths) |path| {
        const unit_tests = b.addTest(.{
            .root_source_file = .{ .path = path },
        });
        inline for (sol_modules) |package| {
            unit_tests.addModule(package.name, package.module);
        }
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}

pub fn allSolModules(b: *std.build.Builder, comptime base_dir: []const u8) [6]std.build.ModuleDependency {
    const base58 = .{ .name = "base58", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "base58/base58.zig" },
    }) };

    const bincode = .{ .name = "bincode", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "bincode/bincode.zig" },
    }) };

    const borsh = .{ .name = "borsh", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "borsh/borsh.zig" },
    }) };

    const sol = .{ .name = "sol", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "sol.zig" },
        .dependencies = &.{
            base58,
            bincode,
        },
    }) };

    const spl = .{ .name = "spl", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "spl/spl.zig" },
        .dependencies = &.{
            sol,
            bincode,
        },
    }) };

    const metaplex = .{ .name = "metaplex", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "metaplex/metaplex.zig" },
        .dependencies = &.{
            sol,
            borsh,
        },
    }) };

    return [_]std.build.ModuleDependency{
        base58,
        bincode,
        borsh,
        sol,
        spl,
        metaplex,
    };
}

pub fn buildProgram(b: *std.build.Builder, program: *std.build.LibExeObjStep, comptime base_dir: []const u8) !void {
    const sol_modules = allSolModules(b, base_dir);

    inline for (sol_modules) |package| {
        program.addModule(package.name, package.module);
    }
    b.installArtifact(program);

    try linkSolanaProgram(b, program);
    //try @import("base58/build.zig").generateProgramKeypair(b, program);
}

pub const sbf_target: std.zig.CrossTarget = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.featureSet(&.{.solana}),
};

pub const sbfv2_target: std.zig.CrossTarget = .{
    .cpu_arch = .sbf,
    .cpu_model = .{
        .explicit = &std.Target.sbf.cpu.sbfv2,
    },
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.cpu.sbfv2.features,
};

pub const bpf_target: std.zig.CrossTarget = .{
    .cpu_arch = .bpfel,
    .os_tag = .freestanding,
    .cpu_features_add = std.Target.bpf.featureSet(&.{.solana}),
};

pub fn linkSolanaProgram(b: *std.build.Builder, lib: *std.build.LibExeObjStep) !void {
    const linker_script = b.addWriteFile("bpf.ld",
        \\PHDRS
        \\{
        \\text PT_LOAD  ;
        \\rodata PT_LOAD ;
        \\dynamic PT_DYNAMIC ;
        \\}
        \\
        \\SECTIONS
        \\{
        \\. = SIZEOF_HEADERS;
        \\.text : { *(.text*) } :text
        \\.rodata : { *(.rodata*) } :rodata
        \\.data.rel.ro : { *(.data.rel.ro*) } :rodata
        \\.dynamic : { *(.dynamic) } :dynamic
        \\}
    );

    lib.step.dependOn(&linker_script.step);

    lib.stack_size = 4096;
    lib.linker_script = linker_script.files.items[0].getPath();
    lib.entry_symbol_name = "entrypoint";
    lib.force_pic = true;
    lib.strip = true;
    lib.link_z_notext = true;
}
