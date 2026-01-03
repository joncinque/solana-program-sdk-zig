//! Solana syscalls - Function pointers with MurmurHash3-32 hashes
//!
//! Syscalls are invoked via function pointers from magic constants.
//! These constants are MurmurHash3-32 hashes of the syscall names.
//! The Solana VM resolves these at runtime via `call -0x1` instruction.
//!
//! Based on: https://github.com/anza-xyz/solana-sdk/blob/master/define-syscall/src/definitions.rs

const builtin = @import("builtin");

/// Check if we're running as a BPF/SBF program
pub const is_bpf_program = !builtin.is_test and
    ((builtin.os.tag == .freestanding and builtin.cpu.arch == .bpfel) or
        (builtin.os.tag == .solana and builtin.cpu.arch == .sbf));

// ============================================================================
// Logging syscalls
// ============================================================================

/// sol_log_
/// Hash: 0x207559bd
pub const sol_log_ = @as(*align(1) const fn ([*]const u8, u64) callconv(.c) void, @ptrFromInt(0x207559bd));

/// sol_log_64_
/// Hash: 0x5c2a3178
pub const sol_log_64_ = @as(*align(1) const fn (u64, u64, u64, u64, u64) callconv(.c) void, @ptrFromInt(0x5c2a3178));

/// sol_log_compute_units_
/// Hash: 0x52ba5096
pub const sol_log_compute_units_ = @as(*align(1) const fn () callconv(.c) void, @ptrFromInt(0x52ba5096));

/// sol_log_pubkey
/// Hash: 0x7ef088ca
pub const sol_log_pubkey = @as(*align(1) const fn ([*]const u8) callconv(.c) void, @ptrFromInt(0x7ef088ca));

/// sol_log_data
/// Hash: 0x7317b434
pub const sol_log_data = @as(*align(1) const fn ([*]const [*]const u8, u64) callconv(.c) void, @ptrFromInt(0x7317b434));

// ============================================================================
// Hashing syscalls
// ============================================================================

/// sol_sha256
/// Hash: 0x11f49d86
pub const sol_sha256 = @as(*align(1) const fn ([*]const [*]const u8, u64, [*]u8) callconv(.c) u64, @ptrFromInt(0x11f49d86));

/// sol_keccak256
/// Hash: 0xd7793abb
pub const sol_keccak256 = @as(*align(1) const fn ([*]const [*]const u8, u64, [*]u8) callconv(.c) u64, @ptrFromInt(0xd7793abb));

/// sol_blake3
/// Hash: 0x174c5122
pub const sol_blake3 = @as(*align(1) const fn ([*]const [*]const u8, u64, [*]u8) callconv(.c) u64, @ptrFromInt(0x174c5122));

/// sol_poseidon
/// Hash: 0xc4947c21
pub const sol_poseidon = @as(*align(1) const fn (u64, u64, [*]const u8, u64, [*]u8) callconv(.c) u64, @ptrFromInt(0xc4947c21));

// ============================================================================
// Memory syscalls
// ============================================================================

/// sol_memcpy_
/// Hash: 0x717cc4a3
pub const sol_memcpy_ = @as(*align(1) const fn ([*]u8, [*]const u8, u64) callconv(.c) void, @ptrFromInt(0x717cc4a3));

/// sol_memmove_
/// Hash: 0x434371f8
pub const sol_memmove_ = @as(*align(1) const fn ([*]u8, [*]const u8, u64) callconv(.c) void, @ptrFromInt(0x434371f8));

/// sol_memcmp_
/// Hash: 0x5fdcde31
pub const sol_memcmp_ = @as(*align(1) const fn ([*]const u8, [*]const u8, u64, [*]i32) callconv(.c) void, @ptrFromInt(0x5fdcde31));

/// sol_memset_
/// Hash: 0x3770fb22
pub const sol_memset_ = @as(*align(1) const fn ([*]u8, u8, u64) callconv(.c) void, @ptrFromInt(0x3770fb22));

// ============================================================================
// Program address syscalls
// ============================================================================

/// sol_create_program_address
/// Hash: 0x9377323c
pub const sol_create_program_address = @as(*align(1) const fn ([*]const [*]const u8, u64, [*]const u8, [*]u8) callconv(.c) u64, @ptrFromInt(0x9377323c));

/// sol_try_find_program_address
/// Hash: 0x48504a38
pub const sol_try_find_program_address = @as(*align(1) const fn ([*]const [*]const u8, u64, [*]const u8, [*]u8, [*]u8) callconv(.c) u64, @ptrFromInt(0x48504a38));

// ============================================================================
// CPI syscalls
// ============================================================================

/// sol_invoke_signed_c
/// Hash: 0xa22b9c85
pub const sol_invoke_signed_c = @as(*align(1) const fn ([*]const u8, [*]const u8, u64, [*]const u8, u64) callconv(.c) u64, @ptrFromInt(0xa22b9c85));

/// sol_invoke_signed_rust
/// Hash: 0xd7449092
pub const sol_invoke_signed_rust = @as(*align(1) const fn ([*]const u8, [*]const u8, u64, [*]const u8, u64) callconv(.c) u64, @ptrFromInt(0xd7449092));

/// sol_set_return_data
/// Hash: 0xa226d3eb
pub const sol_set_return_data = @as(*align(1) const fn ([*]const u8, u64) callconv(.c) void, @ptrFromInt(0xa226d3eb));

/// sol_get_return_data
/// Hash: 0x5d2245e4
pub const sol_get_return_data = @as(*align(1) const fn ([*]u8, u64, [*]u8) callconv(.c) u64, @ptrFromInt(0x5d2245e4));

// ============================================================================
// Crypto syscalls
// ============================================================================

/// sol_secp256k1_recover
/// Hash: 0x17e40350
pub const sol_secp256k1_recover = @as(*align(1) const fn ([*]const u8, u64, [*]const u8, [*]u8) callconv(.c) u64, @ptrFromInt(0x17e40350));

/// sol_alt_bn128_group_op
/// Hash: 0xae0c318b
pub const sol_alt_bn128_group_op = @as(*align(1) const fn (u64, [*]const u8, u64, [*]u8) callconv(.c) u64, @ptrFromInt(0xae0c318b));

/// sol_big_mod_exp
/// Hash: 0x780e4c15
pub const sol_big_mod_exp = @as(*align(1) const fn ([*]const u8, [*]u8) callconv(.c) u64, @ptrFromInt(0x780e4c15));

/// sol_curve_validate_point
/// Hash: 0xaa2607ca
pub const sol_curve_validate_point = @as(*align(1) const fn (u64, [*]const u8, [*]u8) callconv(.c) u64, @ptrFromInt(0xaa2607ca));

/// sol_curve_group_op
/// Hash: 0xdd1c41a6
pub const sol_curve_group_op = @as(*align(1) const fn (u64, u64, [*]const u8, [*]const u8, [*]u8) callconv(.c) u64, @ptrFromInt(0xdd1c41a6));

// ============================================================================
// Sysvar syscalls
// ============================================================================

/// sol_get_clock_sysvar
/// Hash: 0xd56b5fe9
pub const sol_get_clock_sysvar = @as(*align(1) const fn ([*]u8) callconv(.c) u64, @ptrFromInt(0xd56b5fe9));

/// sol_get_epoch_schedule_sysvar
/// Hash: 0x7cfb8d59
pub const sol_get_epoch_schedule_sysvar = @as(*align(1) const fn ([*]u8) callconv(.c) u64, @ptrFromInt(0x7cfb8d59));

/// sol_get_rent_sysvar
/// Hash: 0x51fd556e
pub const sol_get_rent_sysvar = @as(*align(1) const fn ([*]u8) callconv(.c) u64, @ptrFromInt(0x51fd556e));

/// sol_get_last_restart_slot
/// Hash: 0xa4a11afe
pub const sol_get_last_restart_slot = @as(*align(1) const fn ([*]u8) callconv(.c) u64, @ptrFromInt(0xa4a11afe));

/// sol_get_sysvar
/// Hash: 0x13c1b505
pub const sol_get_sysvar = @as(*align(1) const fn ([*]const u8, [*]u8, u64, u64) callconv(.c) u64, @ptrFromInt(0x13c1b505));

// ============================================================================
// Misc syscalls
// ============================================================================

/// sol_get_stack_height
/// Hash: 0x85532d94
pub const sol_get_stack_height = @as(*align(1) const fn () callconv(.c) u64, @ptrFromInt(0x85532d94));

/// sol_remaining_compute_units
/// Hash: 0xedef5aee
pub const sol_remaining_compute_units = @as(*align(1) const fn () callconv(.c) u64, @ptrFromInt(0xedef5aee));

/// abort (panic)
/// Hash: 0xe31de8c1
pub const abort = @as(*align(1) const fn () callconv(.c) noreturn, @ptrFromInt(0xe31de8c1));

// ============================================================================
// Convenience wrappers (use comptime to avoid std in BPF mode)
// ============================================================================

/// Log a message
pub fn log(message: []const u8) void {
    if (comptime is_bpf_program) {
        sol_log_(message.ptr, message.len);
    } else {
        const std = @import("std");
        std.debug.print("{s}\n", .{message});
    }
}

/// Log 5 u64 values
pub fn log64(arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) void {
    if (comptime is_bpf_program) {
        sol_log_64_(arg1, arg2, arg3, arg4, arg5);
    } else {
        const std = @import("std");
        std.debug.print("{} {} {} {} {}\n", .{ arg1, arg2, arg3, arg4, arg5 });
    }
}

/// Log current compute units consumed
pub fn logComputeUnits() void {
    if (comptime is_bpf_program) {
        sol_log_compute_units_();
    } else {
        const std = @import("std");
        std.debug.print("Compute units not available in test mode\n", .{});
    }
}

/// Get remaining compute units
pub fn getRemainingComputeUnits() u64 {
    if (comptime is_bpf_program) {
        return sol_remaining_compute_units();
    } else {
        return 0;
    }
}

/// Log a pubkey
pub fn logPubkey(pubkey: [*]const u8) void {
    if (comptime is_bpf_program) {
        sol_log_pubkey(pubkey);
    }
}
