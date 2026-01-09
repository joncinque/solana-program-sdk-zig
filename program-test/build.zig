const std = @import("std");
const solana = @import("solana_program_sdk");
const base58 = @import("base58");

pub fn build(b: *std.Build) !void {
    const optimize = .ReleaseFast;

    //const target = b.resolveTargetQuery(.{
        //.cpu_arch = .sbf,
        //.os_tag = .solana,
    //});
    const target = b.resolveTargetQuery(solana.bpf_target);
    const name = "pubkey";
    const program = b.addLibrary(.{
        .name = name,
        //.linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("pubkey/main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    solana.linkSolanaProgram(b, program);
    program.lto = .full;
    const solana_dep = b.dependency("solana_program_sdk", .{
        .target = target,
        .optimize = optimize,
    });
    const solana_mod = solana_dep.module("solana_program_sdk");
    program.root_module.addImport("solana_program_sdk", solana_mod);

    const program_so_path = "zig-out/lib/pubkey.so";
    const link_program = b.addSystemCommand(&.{
        "/home/jon/sbpf-linker",
        "--cpu", "v2",  // v2: No 32-bit jumps (Solana sBPF compatible)
        "--llvm-args=-bpf-stack-size=4096",  // Configure 4KB stack for Solana sBPF
        "--export", "entrypoint",
        "-o", program_so_path,
        "zig-out/lib/libpubkey.a", // program.out_filename,
    });
    link_program.step.dependOn(&program.step);

    // Adding required dependencies, link the program properly, and get a
    // prepared modules
    //_ = solana.buildProgram(b, program, target, optimize);
    b.getInstallStep().dependOn(&link_program.step);
    b.installArtifact(program);
    //base58.generateProgramKeypair(b, program);
}
