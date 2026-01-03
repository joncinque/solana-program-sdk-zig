const std = @import("std");

const Account = @import("account.zig").Account;
const ACCOUNT_DATA_PADDING = @import("account.zig").ACCOUNT_DATA_PADDING;
const allocator = @import("allocator.zig").allocator;
const PublicKey = @import("public_key.zig").PublicKey;

pub const Context = struct {
    num_accounts: u64,
    // MAX support parse account number is 64
    accounts: [MAX_ACCOUNTS]Account,
    data: []const u8,
    program_id: *align(1) PublicKey,

    // FUTURE: maybe future change this number
    const MAX_ACCOUNTS = 64;

    pub fn load(input: [*]u8) !Context {
        var ptr: [*]u8 = input;

        // Get the number of accounts
        const num_accounts: *u64 = @ptrCast(@alignCast(ptr));
        // Check if the number of accounts is within the supported range
        if (num_accounts.* > MAX_ACCOUNTS) {
            return error.MaxAccountsExceeded;
        }
        // next ptr point to account data
        ptr += @sizeOf(u64);

        // Account Parse
        var i: usize = 0;
        var accounts: [MAX_ACCOUNTS]Account = undefined;
        while (i < num_accounts.*) : (i += 1) {
            const data: *Account.Data = @ptrCast(@alignCast(ptr));
            if (data.duplicate_index != std.math.maxInt(u8)) {
                ptr += @sizeOf(u64);
                accounts[i] = accounts[data.duplicate_index];
            } else {
                accounts[i] = Account.fromDataPtr(data);
                ptr += Account.DATA_HEADER + data.data_len + ACCOUNT_DATA_PADDING + @sizeOf(u64);
                ptr = @ptrFromInt(std.mem.alignForward(u64, @intFromPtr(ptr), @alignOf(u64)));
            }
        }

        const data_len: *u64 = @ptrCast(@alignCast(ptr));
        ptr += @sizeOf(u64);

        const data = ptr[0..data_len.*];
        ptr += data_len.*;

        const program_id = @as(*align(1) PublicKey, @ptrCast(ptr));

        return Context{
            .num_accounts = num_accounts.*,
            .accounts = accounts,
            .data = data,
            .program_id = program_id,
        };
    }
};
