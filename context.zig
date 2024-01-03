const std = @import("std");

const Account = @import("account.zig").Account;
const allocator = @import("allocator.zig");
const PublicKey = @import("public_key.zig").PublicKey;

const UnalignedAccountPtr: type = *align(1) Account.Data;
const AccountOrIndex = union(enum) { account: Account, index: usize };

const AccountIterator = struct {
    num_accounts: usize,
    i: usize,
    ptr: [*]u8,
    fn next(self: *AccountIterator) ?AccountOrIndex {
        if (self.i < self.num_accounts) {
            self.i += 1;
            const data: UnalignedAccountPtr = @ptrCast(self.ptr);
            if (data.duplicate_index != std.math.maxInt(u8)) {
                self.ptr += @sizeOf(usize);
                return AccountOrIndex { .index = data.duplicate_index };
            }

            const start = @intFromPtr(self.ptr);
            self.ptr += @sizeOf(Account.Data);
            self.ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(usize, @intFromPtr(self.ptr + data.data_len + 10 * 1024), @alignOf(usize))));
            self.ptr += @sizeOf(u64);
            const end = @intFromPtr(self.ptr);

            const account = .{ .ptr = @as(*Account.Data, @ptrCast(@alignCast(data))), .len = end - start };
            return AccountOrIndex { .account = account };
        } else {
            return null;
        }
    }
};

pub const Context = struct {
    num_accounts: usize,
    accounts: [*]u8,
    data: []const u8,
    program_id: *PublicKey,

    pub fn load(input: [*]u8) !Context {
        var ptr: [*]u8 = input;

        const num_accounts = std.mem.bytesToValue(usize, ptr[0..@sizeOf(usize)]);
        ptr += @sizeOf(usize);

        const accounts: [*]u8 = ptr;

        var iter = AccountIterator {
            .num_accounts = num_accounts,
            .ptr = ptr,
            .i = 0,
        };
        while (iter.next()) |_| {}
        ptr = iter.ptr;

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

    pub fn loadRawAccounts(self: Context, gpa: std.mem.Allocator) !std.ArrayList(Account){
        var accounts = try std.ArrayList(Account).initCapacity(gpa, self.num_accounts);
        errdefer accounts.deinit();
        var iter = AccountIterator {
            .num_accounts = self.num_accounts,
            .ptr = self.accounts,
            .i = 0,
        };
        while (iter.next()) |maybe_account| {
            switch (maybe_account) {
                .account => |account| try accounts.append(account),
                .index => |index| try accounts.append(accounts.items[index]),
            }
        }
        return accounts;
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
            inline for (@typeInfo(Accounts).Struct.fields, 0..) |field, i| {
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
                        const start = @intFromPtr(ptr);
                        ptr += @sizeOf(Account.Data);
                        ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(@intFromPtr(ptr + account.data_len + 10 * 1024), @alignOf(usize))));
                        ptr += @sizeOf(u64);
                        const end = @intFromPtr(ptr);

                        @field(accounts, field.name) = .{ .ptr = @as(*Account.data, @ptrCast(@alignCast(account))), .len = end - start };
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
                            const start = @intFromPtr(ptr);
                            ptr += @sizeOf(Account.Data);
                            ptr = @as([*]u8, @ptrFromInt(std.mem.alignForward(@intFromPtr(ptr + account.data_len + 10 * 1024), @alignOf(usize))));
                            ptr += @sizeOf(u64);
                            const end = @intFromPtr(ptr);

                            remaining_account.* = .{ .ptr = @as(*Account.data, @ptrCast(@alignCast(account))), .len = end - start };
                        }
                    }

                    @field(accounts, field.name) = remaining_accounts;
                },
                else => @compileError(""),
            }
        }
    }
};
