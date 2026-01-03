const std = @import("std");
const builtin = @import("builtin");
const syscalls = @import("syscalls.zig");

/// Log a message to the Solana runtime
pub inline fn log(message: []const u8) void {
    if (comptime syscalls.is_bpf_program) {
        syscalls.sol_log_(message.ptr, message.len);
    } else {
        std.debug.print("{s}\n", .{message});
    }
}

/// Print a formatted message
/// Note: In BPF mode, formatting is limited. Use logPubkey for public keys.
pub fn print(comptime format: []const u8, args: anytype) void {
    if (comptime syscalls.is_bpf_program) {
        // In BPF mode, we can only log simple strings
        // Complex formatting (like {f} for PublicKey) is not supported
        // Use logPubkey() for public keys, log64() for numbers
        if (args.len == 0) {
            log(format);
        } else {
            // Just log the format string - args are not supported in BPF
            log(format);
        }
        return;
    }
    std.debug.print(format ++ "\n", args);
}

/// Log the current compute units consumed
pub inline fn logComputeUnits() void {
    if (comptime syscalls.is_bpf_program) {
        syscalls.sol_log_compute_units_();
    }
}

/// Log 5 u64 values
pub inline fn log64(arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) void {
    if (comptime syscalls.is_bpf_program) {
        syscalls.sol_log_64_(arg1, arg2, arg3, arg4, arg5);
    } else {
        std.debug.print("{} {} {} {} {}\n", .{ arg1, arg2, arg3, arg4, arg5 });
    }
}

/// Log a public key
pub inline fn logPubkey(pubkey: [*]const u8) void {
    if (comptime syscalls.is_bpf_program) {
        syscalls.sol_log_pubkey(pubkey);
    }
}

/// Get remaining compute units
pub inline fn getRemainingComputeUnits() u64 {
    if (comptime syscalls.is_bpf_program) {
        return syscalls.sol_remaining_compute_units();
    } else {
        return 0;
    }
}

/// Log data slices (for event emission)
pub inline fn logData(data: []const []const u8) void {
    if (comptime syscalls.is_bpf_program) {
        syscalls.sol_log_data(@ptrCast(data.ptr), data.len);
    }
}
