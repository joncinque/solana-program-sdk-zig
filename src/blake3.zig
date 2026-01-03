const syscalls = @import("syscalls.zig");
const log = @import("log.zig");
const Hash = @import("hash.zig").Hash;

/// Return a Blake3 hash for the given data.
pub fn hashv(vals: []const []const u8) !Hash {
    var hash: Hash = undefined;
    if (syscalls.is_bpf_program) {
        const result = syscalls.sol_blake3(@ptrCast(vals.ptr), vals.len, &hash.bytes);
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
