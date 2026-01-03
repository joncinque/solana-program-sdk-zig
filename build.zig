const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Export self as a module
    const solana_mod = b.addModule("solana_program_sdk", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");
    solana_mod.addImport("base58", base58_mod);

    const lib_unit_tests = b.addTest(.{
        .root_module = solana_mod,
    });

    lib_unit_tests.root_module.addImport("base58", base58_mod);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

// ============================================================================
// Target configuration
// ============================================================================

/// BPF target for standard Zig (bpfel-freestanding)
/// Use with sbpf-linker for the final link step to produce Solana eBPF
pub const bpf_target: std.Target.Query = .{
    .cpu_arch = .bpfel,
    .os_tag = .freestanding,
};

// ============================================================================
// Solana Program Build Helpers (sbpf-linker based)
// ============================================================================

/// Options for building a Solana program
pub const ProgramOptions = struct {
    /// Program name (used for output files)
    name: []const u8,
    /// Root source file for the program
    root_source_file: std.Build.LazyPath,
    /// Optimization mode (default: ReleaseSmall)
    optimize: std.builtin.OptimizeMode = .ReleaseSmall,
};

/// Result of addSolanaProgram - contains build steps and output paths
pub const SolanaProgram = struct {
    /// Step that generates LLVM bitcode (.bc file)
    bitcode_step: *std.Build.Step.Run,
    /// Step that links bitcode to Solana eBPF (.so file)
    /// Requires sbpf-linker to be installed
    link_step: *std.Build.Step.Run,
    /// Install step for the .so file
    install_step: *std.Build.Step,

    /// Get the install step to depend on for the final .so
    pub fn getInstallStep(self: SolanaProgram) *std.Build.Step {
        return self.install_step;
    }
};

/// Build a Solana program using standard Zig + sbpf-linker
///
/// Two-stage build pipeline:
/// 1. Zig → LLVM bitcode (bpfel-freestanding target)
/// 2. sbpf-linker → Solana eBPF (.so file)
///
/// Example:
/// ```zig
/// const solana = @import("solana_program_sdk");
///
/// pub fn build(b: *std.Build) void {
///     const program = solana.addSolanaProgram(b, .{
///         .name = "my_program",
///         .root_source_file = b.path("src/main.zig"),
///     });
///     b.getInstallStep().dependOn(program.getInstallStep());
/// }
/// ```
pub fn addSolanaProgram(b: *std.Build, options: ProgramOptions) SolanaProgram {
    const name = options.name;
    const optimize = options.optimize;

    // Get SDK and base58 module paths
    const solana_dep = b.dependency("solana_program_sdk", .{});
    const sdk_path = solana_dep.path("src/root.zig");
    const base58_dep = b.dependency("base58", .{});
    const base58_path = base58_dep.path("src/root.zig");

    // Output paths
    const bc_filename = b.fmt("{s}.bc", .{name});
    const so_filename = b.fmt("{s}.so", .{name});

    // Create output directory
    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/lib" });

    // Stage 1: Generate LLVM bitcode
    // Module dependency chain: root -> sdk -> base58
    const gen_bitcode = b.addSystemCommand(&.{
        "zig",
        "build-lib",
        "-target",
        "bpfel-freestanding",
        "-O",
        @tagName(optimize),
        "-fPIC",
        "-fno-emit-bin",
        b.fmt("-femit-llvm-bc=zig-out/lib/{s}", .{bc_filename}),
        "--dep",
        "sdk",
    });
    gen_bitcode.addPrefixedFileArg("-Mroot=", options.root_source_file);
    // SDK module with base58 dependency
    gen_bitcode.addArg("--dep");
    gen_bitcode.addArg("base58");
    gen_bitcode.addPrefixedFileArg("-Msdk=", sdk_path);
    // base58 module
    gen_bitcode.addPrefixedFileArg("-Mbase58=", base58_path);
    gen_bitcode.step.dependOn(&mkdir.step);

    // Stage 2: Link with sbpf-linker
    // Note: sbpf-linker requires LLVM shared libraries at runtime
    // We use sh -c to set LD_LIBRARY_PATH and suppress LLVM search warnings
    const link_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt(
            "LD_LIBRARY_PATH=/usr/lib/llvm-18/lib sbpf-linker --cpu v2 --llvm-args=-bpf-stack-size=4096 --export entrypoint -o zig-out/lib/{s} zig-out/lib/{s} 2>/dev/null",
            .{ so_filename, bc_filename },
        ),
    });
    link_cmd.step.dependOn(&gen_bitcode.step);

    // Install step
    const install_step = b.allocator.create(std.Build.Step) catch @panic("OOM");
    install_step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = b.fmt("install {s}", .{name}),
        .owner = b,
    });
    install_step.dependOn(&link_cmd.step);

    return .{
        .bitcode_step = gen_bitcode,
        .link_step = link_cmd,
        .install_step = install_step,
    };
}

/// Add a Solana program with unit tests
///
/// Returns the program build and also sets up a test step
pub fn addSolanaProgramWithTests(
    b: *std.Build,
    options: ProgramOptions,
    test_step: *std.Build.Step,
) SolanaProgram {
    const program = addSolanaProgram(b, options);

    // Add unit tests (run on host)
    const base58_dep = b.dependency("base58", .{});
    const solana_dep = b.dependency("solana_program_sdk", .{});

    const test_sdk_mod = b.createModule(.{
        .root_source_file = solana_dep.path("src/root.zig"),
        .target = b.graph.host,
        .optimize = options.optimize,
    });
    test_sdk_mod.addImport("base58", base58_dep.module("base58"));

    const test_module = b.createModule(.{
        .root_source_file = options.root_source_file,
        .target = b.graph.host,
        .optimize = options.optimize,
    });
    test_module.addImport("sdk", test_sdk_mod);
    test_module.addImport("solana_program_sdk", test_sdk_mod);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_tests.step);

    return program;
}
