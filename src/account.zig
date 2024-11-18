const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

pub const ACCOUNT_DATA_PADDING = 10 * 1024;

pub const Account = struct {
    pub const DATA_HEADER = 88;
    /// A Solana account sliced from what is provided as inputs to the BPF virtual machine.
    pub const Data = packed struct {
        duplicate_index: u8,
        is_signer: u8,
        is_writable: u8,
        is_executable: u8,
        original_data_len: u32,
        id: PublicKey,
        owner_id: PublicKey,
        lamports: u64,
        data_len: u64,

        comptime {
            std.debug.assert(@offsetOf(Account.Data, "duplicate_index") == 0);
            std.debug.assert(@offsetOf(Account.Data, "is_signer") == 0 + 1);
            std.debug.assert(@offsetOf(Account.Data, "is_writable") == 0 + 1 + 1);
            std.debug.assert(@offsetOf(Account.Data, "is_executable") == 0 + 1 + 1 + 1);
            std.debug.assert(@offsetOf(Account.Data, "original_data_len") == 0 + 1 + 1 + 1 + 1);
            std.debug.assert(@offsetOf(Account.Data, "id") == 0 + 1 + 1 + 1 + 1 + 4);
            std.debug.assert(@offsetOf(Account.Data, "owner_id") == 0 + 1 + 1 + 1 + 1 + 4 + 32);
            std.debug.assert(@offsetOf(Account.Data, "lamports") == 0 + 1 + 1 + 1 + 1 + 4 + 32 + 32);
            std.debug.assert(@offsetOf(Account.Data, "data_len") == 0 + 1 + 1 + 1 + 1 + 4 + 32 + 32 + 8);
            std.debug.assert(@bitSizeOf(Account.Data) == DATA_HEADER * 8);
        }
    };

    /// Metadata representing a Solana acconut.
    pub const Param = extern struct {
        id: *const PublicKey,
        is_writable: bool,
        is_signer: bool,
    };

    pub const Info = extern struct {
        id: *const PublicKey,
        lamports: *u64,
        data_len: u64,
        data: [*]u8,
        owner_id: *const PublicKey,
        rent_epoch: u64,
        is_signer: bool,
        is_writable: bool,
        is_executable: bool,
    };

    ptr: *Account.Data,

    pub fn fromDataPtr(ptr: *Account.Data) Account {
        return Account { .ptr = ptr };
    }

    pub fn id(self: Account) PublicKey {
        return self.ptr.id;
    }

    pub fn lamports(self: Account) *u64 {
        return &self.ptr.lamports;
    }

    pub fn ownerId(self: Account) PublicKey {
        return self.ptr.owner_id;
    }

    pub fn assign(self: Account, new_owner_id: PublicKey) void {
        self.ptr.owner_id = new_owner_id;
    }

    pub fn data(self: Account) []u8 {
        const data_ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.ptr))) + DATA_HEADER;
        return data_ptr[0..self.ptr.data_len];
    }

    pub fn isWritable(self: Account) bool {
        return self.ptr.is_writable == 1;
    }

    pub fn isExecutable(self: Account) bool {
        return self.ptr.is_executable == 1;
    }

    pub fn isSigner(self: Account) bool {
        return self.ptr.is_signer == 1;
    }

    pub fn dataLen(self: Account) u64 {
        return self.ptr.data_len;
    }

    pub fn realloc(self: Account, new_data_len: u64) error.InvalidRealloc!void {
        const diff = @subWithOverflow(new_data_len, self.original_data_len);
        if (diff[1] == 0 and diff[0] > ACCOUNT_DATA_PADDING) {
            return error.InvalidRealloc;
        }
        self.reallocUnchecked(new_data_len);
    }

    pub fn reallocUnchecked(self: Account, new_data_len: u64) void {
        self.ptr.data_len = new_data_len;
    }

    pub fn info(self: Account) Account.Info {
        const data_ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.ptr))) + DATA_HEADER;
        const rent_epoch = @as(*u64, @ptrFromInt(std.mem.alignForward(u64, @intFromPtr(self.ptr) + self.ptr.data_len + ACCOUNT_DATA_PADDING, @alignOf(u64))));

        return .{
            .id = &self.ptr.id,
            .lamports = &self.ptr.lamports,
            .data_len = self.ptr.data_len,
            .data = data_ptr,
            .owner_id = &self.ptr.owner_id,
            .rent_epoch = rent_epoch.*,
            .is_signer = self.ptr.is_signer,
            .is_writable = self.ptr.is_writable,
            .is_executable = self.ptr.is_executable,
        };
    }
};
