const bpf = @import("bpf.zig");
const log = @import("log.zig");
const Hash = @import("hash.zig").Hash;

/// Return a Blake3 hash for the given data.
pub fn hashv(vals: []const []const u8) !Hash {
    var hash: Hash = undefined;
    if (bpf.is_bpf_program) {
        const Syscall = struct {
            extern fn sol_blake3(
                vals_ptr: [*]const []const u8,
                vals_len: u64,
                hash_ptr: *Hash,
            ) callconv(.c) u64;
        };
        const result = Syscall.sol_blake3(vals.ptr, vals.len, &hash);
        if (result != 0) {
            log.print("failed to get blake3 hash: error code {}", .{result});
            return error.Unexpected;
        }
    } else {
        log.log("cannot calculate blake3 hash in non-bpf context");
        return error.Unexpected;
    }
    return hash;
}
