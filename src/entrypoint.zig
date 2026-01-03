const PublicKey = @import("public_key.zig").PublicKey;
const Account = @import("account.zig").Account;
const ProgramError = @import("error.zig").ProgramError;
const Context = @import("context.zig").Context;

/// Result type for process instruction functions
pub const ProgramResult = union(enum) {
    ok: void,
    err: ProgramError,
};

/// Function signature for process instruction handlers
pub const ProcessInstruction = *const fn (
    program_id: *PublicKey,
    accounts: []Account,
    data: []const u8,
) ProgramResult;

pub fn declareEntrypoint(comptime process_instruction: ProcessInstruction) void {
    const S = struct {
        pub export fn entrypoint(input: [*]u8) callconv(.c) u64 {
            var context = Context.load(input) catch return 1;
            const result = process_instruction(context.program_id, context.accounts[0..context.num_accounts], context.data);
            return switch (result) {
                .ok => 0,
                .err => |e| e.toU64(),
            };
        }
    };
    _ = &S.entrypoint;
}

/// Helper macro-like function for simple entrypoint declaration
pub inline fn entrypoint(comptime process_instruction: ProcessInstruction) void {
    declareEntrypoint(process_instruction);
}
