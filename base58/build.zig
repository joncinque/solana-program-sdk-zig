const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    buildKeygen(b, "");
}

pub fn buildKeygen(b: *std.build.Builder, comptime base_dir: []const u8) *std.build.Step.Compile {
    const keygen_exe = b.addExecutable(.{
        .name = "keygen",
        .root_source_file = .{ .path = base_dir ++ "keygen.zig" },
    });

    const clap = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "../lib/zig-clap/clap.zig" },
    });
    keygen_exe.addModule("clap", clap);
    b.installArtifact(keygen_exe);
    return keygen_exe;
}

pub fn generateKeypairRunStep(b: *std.build.Builder, comptime base_dir: []const u8, path: []const u8) !*std.Build.Step.Run {
    const exe = buildKeygen(b, base_dir);
    const run_exe = b.addRunArtifact(exe);
    run_exe.addArg("-o");
    run_exe.addFileArg(.{ .path = path });
    return run_exe;
}
