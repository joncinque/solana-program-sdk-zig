const std = @import("std");
const base58 = @import("base58");

pub const Hash = struct {
    pub const length: usize = 32;
    bytes: [Hash.length]u8,

    pub fn format(self: Hash, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        var buffer: [base58.bitcoin.getEncodedLengthUpperBound(Hash.length)]u8 = undefined;
        try writer.print("{s}", .{base58.bitcoin.encode(&buffer, &self.bytes)});
    }
};
