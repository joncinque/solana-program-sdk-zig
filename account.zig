const std = @import("std");
const sol = @import("sol.zig");

pub const Account = struct {
    /// A Solana account sliced from what is provided as inputs to the BPF virtual machine.
    pub const Data = extern struct {
        duplicate_index: u8,
        is_signer: bool,
        is_writable: bool,
        is_executable: bool,
        _: [4]u8,
        id: sol.PublicKey,
        owner_id: sol.PublicKey,
        lamports: u64,
        data_len: usize,

        comptime {
            std.debug.assert(@offsetOf(Account.Data, "duplicate_index") == 0);
            std.debug.assert(@offsetOf(Account.Data, "is_signer") == 0 + 1);
            std.debug.assert(@offsetOf(Account.Data, "is_writable") == 0 + 1 + 1);
            std.debug.assert(@offsetOf(Account.Data, "is_executable") == 0 + 1 + 1 + 1);
            std.debug.assert(@offsetOf(Account.Data, "_") == 0 + 1 + 1 + 1 + 1);
            std.debug.assert(@offsetOf(Account.Data, "id") == 0 + 1 + 1 + 1 + 1 + 4);
            std.debug.assert(@offsetOf(Account.Data, "owner_id") == 0 + 1 + 1 + 1 + 1 + 4 + 32);
            std.debug.assert(@offsetOf(Account.Data, "lamports") == 0 + 1 + 1 + 1 + 1 + 4 + 32 + 32);
            std.debug.assert(@offsetOf(Account.Data, "data_len") == 0 + 1 + 1 + 1 + 1 + 4 + 32 + 32 + 8);
            std.debug.assert(@sizeOf(Account.Data) == 1 + 1 + 1 + 1 + 4 + 32 + 32 + 8 + 8);
        }
    };

    /// Metadata representing a Solana acconut.
    pub const Param = extern struct {
        id: *const sol.PublicKey,
        is_writable: bool,
        is_signer: bool,
    };

    pub const Info = extern struct {
        id: *const sol.PublicKey,
        lamports: *u64,
        data_len: u64,
        data: [*]u8,
        owner_id: *const sol.PublicKey,
        rent_epoch: u64,
        is_signer: bool,
        is_writable: bool,
        is_executable: bool,
    };

    ptr: *Account.Data,
    len: usize,

    pub fn id(self: Account) sol.PublicKey {
        return self.ptr.id;
    }

    pub fn lamports(self: Account) *u64 {
        return &self.ptr.lamports;
    }

    pub fn ownerId(self: Account) sol.PublicKey {
        return self.ptr.owner_id;
    }

    pub fn data(self: Account) []u8 {
        const data_ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.ptr))) + @sizeOf(Account.Data);
        return data_ptr[0..self.ptr.data_len];
    }

    pub fn isWritable(self: Account) bool {
        return self.ptr.is_writable;
    }

    pub fn isExecutable(self: Account) bool {
        return self.ptr.is_executable;
    }

    pub fn isSigner(self: Account) bool {
        return self.ptr.is_signer;
    }

    pub fn dataLen(self: Account) usize {
        return self.ptr.data_len;
    }

    pub fn info(self: Account) Account.Info {
        const data_ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.ptr))) + @sizeOf(Account.Data);
        const rent_epoch = @as(*u64, @ptrFromInt(@intFromPtr(self.ptr) + self.len - @sizeOf(u64)));

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
