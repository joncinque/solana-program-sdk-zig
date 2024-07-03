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

    // Maybe make this better -- we need to add solana's dependency to it too
    const base58_dep = b.dependency("base58", .{
        .target = target,
        .optimize = optimize,
    });
    const base58_mod = base58_dep.module("base58");

    // Adding it as a module
    const solana_dep = b.dependency("solana-program-sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana-program-sdk");
    solana_mod.addImport("base58", base58_mod);
    program.root_module.addImport("solana-program-sdk", solana_mod);

    b.installArtifact(program);
    solana.buildProgram(b, program);
}
