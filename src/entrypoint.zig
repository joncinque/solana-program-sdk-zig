const PublicKey = @import("public_key.zig").PublicKey;
const Account = @import("account.zig").Account;
const ProgramError = @import("error.zig").ProgramError;
const Context = @import("context.zig").Context;

const processInstruction = fn (program_id: *PublicKey, accounts: []Account, data: []const u8) ProgramError!void;

pub fn declareEntrypoint(comptime process_instruction: processInstruction) void {
    const S = struct {
        pub export fn entrypoint(input: [*]u8) callconv(.C) u64 {
            var context = Context.load(input) catch return 1;
            process_instruction(context.program_id, context.accounts[0..context.num_accounts], context.data) catch |err| return @intFromError(err);
            return 0;
        }
    };
    _ = &S.entrypoint;
}

/// Helper macro-like function for simple entrypoint declaration
pub inline fn entrypoint(comptime process_instruction: processInstruction) void {
    declareEntrypoint(process_instruction);
}
