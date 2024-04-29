const std = @import("std");
const sol = @import("sol/sol.zig");

pub fn build(b: *std.Build) !void {
    const program = b.addSharedLibrary(.{
        .name = "pubkey",
        .root_source_file = .{ .path = "pubkey/main.zig" },
        .optimize = .ReleaseFast,
        .target = b.resolveTargetQuery(sol.sbf_target),
    });
    try sol.buildProgram(b, program, "../");
}
