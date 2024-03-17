const std = @import("std");

const base58 = @This();

pub const bitcoin = base58.Alphabet.init("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz");
pub const ipfs = base58.Alphabet.init("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz");
pub const flickr = base58.Alphabet.init("123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ");
pub const ripple = base58.Alphabet.init("rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz");

pub const Alphabet = struct {
    digits_map: [128]u8,
    character_map: [58]u8,

    pub fn init(comptime characters: *const [58]u8) base58.Alphabet {
        var alphabet: base58.Alphabet = .{ .character_map = characters.*, .digits_map = [_]u8{255} ** 128 };

        var distinct: usize = 0;
        for (alphabet.character_map, 0..) |b, i| {
            if (alphabet.digits_map[b] == 255) {
                distinct += 1;
            }
            alphabet.digits_map[b] = @as(i8, i);
        }
        if (distinct != 58) {
            @compileError("base58 alphabet does not consist of 58 distinct characters");
        }
        return alphabet;
    }

    pub fn comptimeEncode(comptime self: base58.Alphabet, comptime decoded: []const u8) [self.comptimeGetEncodedLength(decoded)]u8 {
        comptime {
            @setEvalBranchQuota(100_000);
            var buffer: [self.getEncodedLengthUpperBound(decoded.len)]u8 = undefined;
            const encoded = self.encode(&buffer, decoded);
            return encoded[0..encoded.len].*;
        }
    }

    pub fn comptimeDecode(comptime self: base58.Alphabet, comptime encoded: []const u8) [self.comptimeGetDecodedLength(encoded)]u8 {
        comptime {
            @setEvalBranchQuota(100_000);
            var buffer: [self.getDecodedLengthUpperBound(encoded.len)]u8 = undefined;
            const decoded = self.decode(&buffer, encoded) catch |err| {
                @compileError("failed to decode base58 string: '" ++ @errorName(err) ++ "'");
            };
            return decoded[0..decoded.len].*;
        }
    }

    pub fn comptimeGetDecodedLength(comptime self: base58.Alphabet, comptime encoded: []const u8) usize {
        comptime {
            @setEvalBranchQuota(100_000);

            var decoded = std.mem.zeroes([self.getDecodedLengthUpperBound(encoded.len)]u8);

            var len: usize = 0;
            for (encoded) |r| {
                var val: usize = self.digits_map[r];
                if (val == 255) {
                    @compileError("failed to compute base58 string length: unknown character '" ++ [_]u8{r} ++ "'");
                }
                for (decoded[0..len], 0..) |b, i| {
                    val += @as(u32, b) * 58;
                    decoded[i] = @as(u8, @truncate(val));
                    val >>= 8;
                }
                while (val > 0) : (val >>= 8) {
                    decoded[len] = @as(u8, @truncate(val));
                    len += 1;
                }
            }

            for (encoded) |r| {
                if (r != self.character_map[0]) {
                    break;
                }
                len += 1;
            }

            return len;
        }
    }

    pub fn comptimeGetEncodedLength(comptime self: base58.Alphabet, comptime decoded: []const u8) usize {
        comptime {
            @setEvalBranchQuota(100_000);

            var encoded = std.mem.zeroes([self.getEncodedLengthUpperBound(decoded.len)]u8);

            var len: usize = 0;
            for (decoded) |r| {
                var val: u32 = r;
                for (encoded[0..len], 0..) |b, i| {
                    val += @as(u32, b) << 8;
                    encoded[i] = @as(u8, @intCast(val % 58));
                    val /= 58;
                }
                while (val > 0) : (val /= 58) {
                    encoded[len] = @as(u8, @intCast(val % 58));
                    len += 1;
                }
            }

            for (decoded) |r| {
                if (r != 0) {
                    break;
                }
                len += 1;
            }

            return len;
        }
    }

    pub fn encode(comptime self: base58.Alphabet, encoded: []u8, decoded: []const u8) []const u8 {
        var len: usize = 0;
        for (decoded) |r| {
            var val: usize = r;
            for (encoded[0..len]) |*b| {
                val += @as(usize, b.*) << 8;
                b.* = @intCast(val % 58);
                val /= 58;
            }
            while (val > 0) : (val /= 58) {
                encoded[len] = @intCast(val % 58);
                len += 1;
            }
        }

        for (decoded) |r| {
            if (r != 0) {
                break;
            }
            encoded[len] = 0;
            len += 1;
        }

        for (encoded[0..len], 0..) |b, i| {
            encoded[i] = self.character_map[b];
        }

        std.mem.reverse(u8, encoded[0..len]);

        return encoded[0..len];
    }

    pub fn decode(comptime self: base58.Alphabet, decoded: []u8, encoded: []const u8) ![]const u8 {
        if (encoded.len == 0) {
            return error.ZeroLengthString;
        }

        var len: usize = 0;
        for (encoded) |r| {
            var val: usize = self.digits_map[r];
            if (val == 255) {
                return error.InvalidBase58Digit;
            }
            for (decoded[0..len], 0..) |b, i| {
                val += @as(usize, b) * 58;
                decoded[i] = @as(u8, @truncate(val));
                val >>= 8;
            }
            while (val > 0) : (val >>= 8) {
                decoded[len] = @as(u8, @truncate(val));
                len += 1;
            }
        }

        for (encoded) |r| {
            if (r != self.character_map[0]) {
                break;
            }
            decoded[len] = 0;
            len += 1;
        }

        std.mem.reverse(u8, decoded[0..len]);

        return decoded[0..len];
    }

    /// The max possible number of outputted bytes per input byte is log_58(256)
    /// ~= 1.37. Thus, the max total output size is ceil(decoded_len * 137/100).
    /// Rather than worrying about accurately computing ceil(), add one to the
    /// upper bound even if it isn't necessary.
    pub fn getEncodedLengthUpperBound(comptime self: base58.Alphabet, decoded_len: usize) usize {
        _ = self;
        return decoded_len * 137 / 100 + 1;
    }

    /// A base58 string filled with nothing but the first base58 alphabet
    /// character's decoded length is the length of the itself.
    pub fn getDecodedLengthUpperBound(comptime self: base58.Alphabet, encoded_len: usize) usize {
        _ = self;
        return encoded_len;
    }
};

test "base58: test vectors" {
    inline for (.{
        .{ "Hello World!", "2NEpo7TZRRrLZSi2U" },
        .{ "The quick brown fox jumps over the lazy dog.", "USm3fpXnKG5EUBx2ndxBDMPVciP5hGey2Jh4NDv6gmeo1LkMeiKrLJUUBk6Z" },
        .{ &[_]u8{ 0x00, 0x00, 0x28, 0x7f, 0xb4, 0xcd }, "11233QC4" },
    }) |test_case| {
        try comptime std.testing.expectEqualSlices(u8, test_case[1], &base58.bitcoin.comptimeEncode(test_case[0]));
        try comptime std.testing.expectEqualSlices(u8, test_case[0], &base58.bitcoin.comptimeDecode(test_case[1]));
    }
}
