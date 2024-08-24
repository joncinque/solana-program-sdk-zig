const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Export self as a module
    _ = b.addModule("solana-program-sdk", .{ .root_source_file = b.path("src/root.zig") });

    const lib = b.addStaticLibrary(.{
        .name = "solana-program-sdk",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");
    lib.root_module.addImport("base58", base58_mod);

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn addDependencies(b: *std.Build, solana_mod: *std.Build.Module, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");
    solana_mod.addImport("base58", base58_mod);
}

// General helper function to do all the tricky build steps, by creating the
// solana-sdk module, adding its dependencies, adding the BPF link script
pub fn buildProgram(b: *std.Build, program: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const solana_dep = b.dependency("solana-program-sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana-program-sdk");
    program.root_module.addImport("solana-program-sdk", solana_mod);
    addDependencies(b, solana_mod, target, optimize);
    linkSolanaProgram(b, program);
    return solana_mod;
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

pub fn linkSolanaProgram(b: *std.Build, lib: *std.Build.Step.Compile) void {
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
        \\.data.rel.ro : { *(.data.rel.ro*) } :rodata
        \\.dynamic : { *(.dynamic) } :dynamic
        \\.dynsym : { *(.dynsym) } :data
        \\.dynstr : { *(.dynstr) } :data
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
