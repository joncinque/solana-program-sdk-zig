const sol = @import("solana_program_sdk");

fn processInstruction(program_id: *sol.PublicKey, accounts: []sol.Account, data: []const u8) sol.ProgramError!void {
    _ = accounts;
    _ = data;
    _ = program_id;
    sol.print("Hello zig program", .{});
    return;
}

// Declare the program entrypoint
comptime {
    sol.entrypoint(processInstruction);
}
