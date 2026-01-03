const std = @import("std");
const solana = @import("solana_program_sdk");
const base58 = @import("base58");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;
    const target = b.resolveTargetQuery(solana.sbf_target);
    const program = b.addLibrary(.{
        .name = "pubkey",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("pubkey/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    // Adding required dependencies, link the program properly, and get a
    // prepared modules
    _ = solana.buildProgram(b, program, target, optimize);
    b.installArtifact(program);
    base58.generateProgramKeypair(b, program);
}
