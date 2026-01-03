const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    // Build option: which program to build
    const program_name = b.option([]const u8, "program", "Program to build") orelse "pubkey";

    // Program source path
    const program_path = b.fmt("{s}/main.zig", .{program_name});

    // Build the Solana program using SDK helper
    const test_step = b.step("test", "Run unit tests");
    const program = solana.addSolanaProgramWithTests(b, .{
        .name = program_name,
        .root_source_file = b.path(program_path),
        .optimize = .ReleaseSmall,
    }, test_step);

    // Default install step builds .so
    b.getInstallStep().dependOn(program.getInstallStep());

    // Also add a "bitcode" step for just the .bc file (no sbpf-linker required)
    const bc_step = b.step("bitcode", "Generate LLVM bitcode only (no sbpf-linker required)");
    bc_step.dependOn(&program.bitcode_step.step);
}
