const std = @import("std");
const program = @import("program.zig");

const test_paths = [_][]const u8{
    "system_program.zig",
    "base58/base58.zig",
    "metaplex/metaplex.zig",
    "public_key.zig",
    "sol.zig",
    "spl/token.zig",
    "spl/spl.zig",
};

pub fn build(b: *std.build.Builder) !void {
    const sol_modules = program.allSolModules(b, "");

    const test_step = b.step("test", "Run unit tests");
    inline for (test_paths) |path| {
        const unit_tests = b.addTest(.{
            .root_source_file = .{ .path = path },
        });
        inline for (sol_modules) |package| {
            unit_tests.addModule(package.name, package.module);
        }
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
