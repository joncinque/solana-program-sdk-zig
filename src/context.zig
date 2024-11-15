const std = @import("std");

const Account = @import("account.zig").Account;
const ACCOUNT_DATA_PADDING = @import("account.zig").ACCOUNT_DATA_PADDING;
const allocator = @import("allocator.zig").allocator;
const PublicKey = @import("public_key.zig").PublicKey;

pub const Context = struct {
    num_accounts: usize,
    accounts: [64]Account,
    data: []const u8,
    program_id: *align(1) PublicKey,

    pub fn load(input: [*]u8) !Context {
        var ptr: [*]u8 = input;

        const num_accounts = std.mem.bytesToValue(usize, ptr[0..@sizeOf(usize)]);
        ptr += @sizeOf(usize);

        var i: usize = 0;
        var accounts: [64]Account = undefined;
        while (i < num_accounts) {
            const data: *align(1) Account.Data = @ptrCast(ptr);
            if (data.duplicate_index != std.math.maxInt(u8)) {
                ptr += @sizeOf(usize);
                accounts[i] = accounts[data.duplicate_index];
            } else {
                ptr += Account.DATA_HEADER;
                ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(usize, @intFromPtr(ptr) + data.data_len + ACCOUNT_DATA_PADDING, @alignOf(usize))));
                ptr += @sizeOf(u64);
                accounts[i] = .{ .ptr = @as(*Account.Data, @ptrCast(@alignCast(data))) };
            }
            i += 1;
        }

        const data_len = std.math.cast(usize, std.mem.bytesToValue(u64, ptr[0..@sizeOf(u64)])) orelse return error.DataTooLarge;
        ptr += @sizeOf(u64);

        const data = ptr[0..data_len];
        ptr += data_len;

        const program_id = @as(*align(1) PublicKey, @ptrCast(ptr));
        ptr += @sizeOf(PublicKey);

        return Context{
            .num_accounts = num_accounts,
            .accounts = accounts,
            .data = data,
            .program_id = program_id,
        };
    }
};
