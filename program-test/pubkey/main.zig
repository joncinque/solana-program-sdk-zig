const sol = @import("solana_program_sdk");

fn processInstruction(program_id: *sol.PublicKey, accounts: []sol.Account, data: []const u8) sol.ProgramError!void {
    _ = accounts;
    _ = data;
    sol.print("Hello New processInstruction program {s}", .{program_id});
    return;
}

// Declare the program entrypoint
comptime {
    sol.declareEntrypoint(processInstruction);
}
