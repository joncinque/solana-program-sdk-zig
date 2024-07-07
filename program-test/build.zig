const std = @import("std");
const solana = @import("solana-program-sdk");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseSmall;
    const target = b.resolveTargetQuery(solana.sbf_target);
    const program = b.addSharedLibrary(.{
        .name = "pubkey",
        .root_source_file = .{ .path = "pubkey/main.zig" },
        .optimize = optimize,
        .target = target,
    });

    // Adding required dependencies, link the program properly, and get a
    // prepared modules
    _ = solana.buildProgram(b, program, target, optimize);
}
