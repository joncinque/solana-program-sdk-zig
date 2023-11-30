const std = @import("std");
const PublicKey = @import("public_key.zig").PublicKey;

const SlotHashes = @This();

pub const id = PublicKey.comptimeFromBase58("SysvarS1otHashes111111111111111111111111111");

/// About 2.5 minutes to get your vote in.
pub const max_entries = 512;

pub const SlotHash = struct {
    slot: u64,
    hash: [32]u8,
};

ptr: [*]SlotHash,
len: u64,

pub fn from(data: []const u8) []const SlotHash {
    const len = std.mem.readIntSliceLittle(u64, data[0..@sizeOf(u64)]);
    return @as([*]const SlotHash, @ptrCast(@alignCast(data.ptr + @sizeOf(u64))))[0..len];
}
