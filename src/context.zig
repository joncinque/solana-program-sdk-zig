const std = @import("std");

const Account = @import("account.zig").Account;
const ACCOUNT_DATA_PADDING = @import("account.zig").ACCOUNT_DATA_PADDING;
const allocator = @import("allocator.zig").allocator;
const PublicKey = @import("public_key.zig").PublicKey;

pub const Context = struct {
    num_accounts: usize,
    accounts: [64]Account,
    data: []const u8,
    program_id: *PublicKey,

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
                ptr += @sizeOf(Account.Data);
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

        const program_id = @as(*PublicKey, @ptrCast(ptr));
        ptr += @sizeOf(PublicKey);

        return Context{
            .num_accounts = num_accounts,
            .accounts = accounts,
            .data = data,
            .program_id = program_id,
        };
    }

    pub fn loadAccountsAlloc(self: Context, comptime Accounts: type, gpa: std.mem.Allocator) !*Accounts {
        const accounts = try gpa.create(Accounts);
        errdefer gpa.destroy(accounts);

        try self.populateAccounts(Accounts, accounts);

        return accounts;
    }

    pub fn loadAccounts(self: Context, comptime Accounts: type) !Accounts {
        var accounts: Accounts = undefined;
        try self.populateAccounts(Accounts, &accounts);
        return accounts;
    }

    fn populateAccounts(self: Context, comptime Accounts: type, accounts: *Accounts) !void {
        comptime var min_accounts = 0;
        comptime var last_field_is_slice = false;

        comptime {
            for (@typeInfo(Accounts).Struct.fields, 0..) |field, i| {
                switch (field.type) {
                    Account => min_accounts += 1,
                    []Account => {
                        if (i != @typeInfo(Accounts).Struct.fields.len - 1) {
                            @compileError("Only the last field of an 'Accounts' struct may be a slice of accounts.");
                        }
                        last_field_is_slice = true;
                    },
                    else => @compileError(""),
                }
            }
        }

        if (self.num_accounts < min_accounts) {
            return error.NotEnoughAccounts;
        }

        var ptr: [*]u8 = self.accounts;

        @setEvalBranchQuota(100_000);

        inline for (@typeInfo(Accounts).Struct.fields) |field| {
            switch (field.type) {
                Account => {
                    const account: *align(1) Account.Data = @as(*align(1) Account.Data, @ptrCast(ptr));
                    if (account.duplicate_index != std.math.maxInt(u8)) {
                        inline for (@typeInfo(Accounts).Struct.fields, 0..) |cloned_field, cloned_index| {
                            if (cloned_field.type == Account) {
                                if (account.duplicate_index == cloned_index) {
                                    @field(accounts, field.name) = @field(accounts, cloned_field.name);
                                }
                            }
                        }
                        ptr += @sizeOf(usize);
                    } else {
                        ptr += @sizeOf(Account.Data);
                        ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(@intFromPtr(ptr + account.data_len + ACCOUNT_DATA_PADDING), @alignOf(usize))));
                        ptr += @sizeOf(u64);
                        @field(accounts, field.name) = .{ .ptr = @as(*Account.data, @ptrCast(@alignCast(account))) };
                    }
                },
                []Account => {
                    const remaining_accounts = try allocator.alloc(Account, self.num_accounts + 1 - @typeInfo(Accounts).Struct.fields.len);
                    errdefer allocator.free(remaining_accounts);

                    for (remaining_accounts) |*remaining_account| {
                        const account: *align(1) Account.Data = @as(*align(1) Account.Data, @ptrCast(ptr));
                        if (account.duplicate_index != std.math.maxInt(u8)) {
                            inline for (@typeInfo(Accounts).Struct.fields, 0..) |cloned_field, cloned_index| {
                                if (cloned_field.type == Account) {
                                    if (account.duplicate_index == cloned_index) {
                                        remaining_account.* = @field(accounts, cloned_field.name);
                                    }
                                }
                            }
                            ptr += @sizeOf(usize);
                        } else {
                            ptr += @sizeOf(Account.Data);
                            ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(@intFromPtr(ptr + account.data_len + ACCOUNT_DATA_PADDING), @alignOf(usize))));
                            ptr += @sizeOf(u64);
                            remaining_account.* = .{ .ptr = @as(*Account.data, @ptrCast(@alignCast(account))) };
                        }
                    }

                    @field(accounts, field.name) = remaining_accounts;
                },
                else => @compileError(""),
            }
        }
    }
};
