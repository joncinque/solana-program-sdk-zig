const sol = @import("solana-program-sdk");

export fn entrypoint(input: [*]u8) u64 {
    const context = sol.Context.load(input) catch return 1;
    sol.print("Hello zig program {s}", .{context.program_id});
    return 0;
}
