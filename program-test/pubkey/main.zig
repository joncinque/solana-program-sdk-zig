const sol = @import("solana_program_sdk");

export fn entrypoint(input: [*]u8) u64 {
    const context = sol.context.Context.load(input) catch return 1;
    sol.log.print("Hello zig program {f}", .{context.program_id});
    return 0;
}
