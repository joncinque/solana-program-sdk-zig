const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Export self as a module
    const solana_mod = b.addModule("solana_program_sdk", .{ .root_source_file = b.path("src/root.zig") });

    const lib = b.addStaticLibrary(.{
        .name = "solana_program_sdk",
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
    solana_mod.addImport("base58", base58_mod);

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

// General helper function to do all the tricky build steps, by adding the
// solana-sdk module, adding the BPF link script
pub fn buildProgram(b: *std.Build, program: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");
    program.root_module.addImport("solana_program_sdk", solana_mod);
    linkSolanaProgram(b, program);
    return solana_mod;
}

pub const sbf_target: std.Target.Query = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
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
    const write_file_step = b.addWriteFiles();
    const linker_script = write_file_step.add("bpf.ld",
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

    lib.step.dependOn(&write_file_step.step);

    lib.setLinkerScript(linker_script);
    lib.stack_size = 4096;
    lib.link_z_notext = true;
    lib.root_module.pic = true;
    lib.root_module.strip = true;
    lib.entry = .{ .symbol_name = "entrypoint" };
}
