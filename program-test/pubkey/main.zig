const sdk = @import("sdk");

fn processInstruction(program_id: *sdk.PublicKey, accounts: []sdk.Account, data: []const u8) sdk.ProgramResult {
    _ = accounts;
    _ = data;
    sdk.print("Hello zig program!", .{});
    sdk.log.logPubkey(&program_id.bytes);
    return .ok;
}

// Declare the program entrypoint
comptime {
    sdk.entrypoint(&processInstruction);
}
