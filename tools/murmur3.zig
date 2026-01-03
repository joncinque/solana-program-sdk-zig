//! MurmurHash3-32 implementation for Solana syscall hashing
//!
//! Solana uses MurmurHash3-32 with seed=0 to hash syscall names.
//! The resulting hash is used as a function pointer address.

const std = @import("std");

/// MurmurHash3-32 implementation
pub fn murmur3_32(data: []const u8, seed: u32) u32 {
    const c1: u32 = 0xcc9e2d51;
    const c2: u32 = 0x1b873593;
    const r1: u5 = 15;
    const r2: u5 = 13;
    const m: u32 = 5;
    const n: u32 = 0xe6546b64;

    var hash: u32 = seed;
    const len: u32 = @intCast(data.len);

    // Process 4-byte chunks
    const n_blocks = len / 4;
    var i: usize = 0;
    while (i < n_blocks) : (i += 1) {
        const offset = i * 4;
        var k: u32 = @as(u32, data[offset]) |
            (@as(u32, data[offset + 1]) << 8) |
            (@as(u32, data[offset + 2]) << 16) |
            (@as(u32, data[offset + 3]) << 24);

        k *%= c1;
        k = std.math.rotl(u32, k, r1);
        k *%= c2;

        hash ^= k;
        hash = std.math.rotl(u32, hash, r2);
        hash = hash *% m +% n;
    }

    // Process remaining bytes
    const tail_offset = n_blocks * 4;
    const remaining = data.len - tail_offset;
    var k1: u32 = 0;

    if (remaining >= 3) {
        k1 ^= @as(u32, data[tail_offset + 2]) << 16;
    }
    if (remaining >= 2) {
        k1 ^= @as(u32, data[tail_offset + 1]) << 8;
    }
    if (remaining >= 1) {
        k1 ^= @as(u32, data[tail_offset]);
        k1 *%= c1;
        k1 = std.math.rotl(u32, k1, r1);
        k1 *%= c2;
        hash ^= k1;
    }

    // Finalization
    hash ^= len;
    hash ^= hash >> 16;
    hash *%= 0x85ebca6b;
    hash ^= hash >> 13;
    hash *%= 0xc2b2ae35;
    hash ^= hash >> 16;

    return hash;
}

/// Hash a syscall name using MurmurHash3-32 with seed 0
pub fn syscallHash(name: []const u8) u32 {
    return murmur3_32(name, 0);
}

test "murmur3 known values" {
    // Test vectors from Solana SDK
    try std.testing.expectEqual(@as(u32, 0x207559bd), syscallHash("sol_log_"));
    try std.testing.expectEqual(@as(u32, 0x5c2a3178), syscallHash("sol_log_64_"));
    try std.testing.expectEqual(@as(u32, 0x52ba5096), syscallHash("sol_log_compute_units_"));
    try std.testing.expectEqual(@as(u32, 0x174c5122), syscallHash("sol_blake3"));
    try std.testing.expectEqual(@as(u32, 0x9377323c), syscallHash("sol_create_program_address"));
    try std.testing.expectEqual(@as(u32, 0x48504a38), syscallHash("sol_try_find_program_address"));
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        try stdout.print("Usage: murmur3 <syscall_name>\n", .{});
        return;
    }

    const hash = syscallHash(args[1]);
    try stdout.print("0x{x:0>8}\n", .{hash});
}
