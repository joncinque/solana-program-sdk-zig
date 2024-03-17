const std = @import("std");
const sol = @import("sol/sol.zig");

pub fn build(b: *std.build.Builder) !void {
    const optimize = .ReleaseSmall;
    const program = b.addSharedLibrary(.{
        .name = "pubkey",
        .root_source_file = .{ .path = "pubkey/main.zig" },
        .optimize = optimize,
        .target = sol.sbf_target,
    });
    try sol.buildProgram(b, program, "../");
}
