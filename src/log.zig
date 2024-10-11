const std = @import("std");
const bpf = @import("bpf.zig");

pub inline fn log(message: []const u8) void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_log_(ptr: [*]const u8, len: u64) callconv(.C) void;
        };
        Syscall.sol_log_(message.ptr, message.len);
    } else {
        std.debug.print("{s}\n", .{message});
    }
}

pub fn print(comptime format: []const u8, args: anytype) void {
    if (!bpf.is_bpf_program) {
        return std.debug.print(format ++ "\n", args);
    }

    if (args.len == 0) {
        return log(format);
    }

    var buffer: [1024]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, format, args) catch return;
    return log(message);
}

pub inline fn logComputeUnits() void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_log_compute_units_() callconv(.C) void;
        };
        Syscall.sol_log_compute_units_();
    } else {
        std.debug.print("Compute units not available\n");
    }
}

pub inline fn logData(data: []const []const u8) void {
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_log_data(ptr: [*]const []const u8, len: u64) callconv(.C) void;
        };
        Syscall.sol_log_data(data.ptr, data.len);
    } else {
        // TODO base64 encoding
        std.debug.print("{s}\n", .{data});
    }
}
