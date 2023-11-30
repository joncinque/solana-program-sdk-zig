const bpf = @import("bpf.zig");
const log = @import("log.zig");
const PublicKey = @import("public_key.zig").PublicKey;

pub const Clock = extern struct {
    pub const id = PublicKey.comptimeFromBase58("SysvarC1ock11111111111111111111111111111111");

    /// The current network/bank slot
    slot: u64,
    /// The timestamp of the first slot in this Epoch
    epoch_start_timestamp: i64,
    /// The bank epoch
    epoch: u64,
    /// The future epoch for which the leader schedule has
    ///  most recently been calculated
    leader_schedule_epoch: u64,
    /// Originally computed from genesis creation time and network time
    /// in slots (drifty); corrected using validator timestamp oracle as of
    /// timestamp_correction and timestamp_bounding features
    /// An approximate measure of real-world time, expressed as Unix time
    /// (i.e. seconds since the Unix epoch)
    unix_timestamp: i64,

    pub fn get() !Clock {
        var clock: Clock = undefined;
        if (bpf.is_bpf_program) {
            const Syscall = struct {
                extern fn sol_get_clock_sysvar(ptr: *Clock) callconv(.C) u64;
            };
            const result = Syscall.sol_get_clock_sysvar(&clock);
            if (result != 0) {
                log.print("failed to get clock sysvar: error code {}", .{result});
                return error.Unexpected;
            }
        }
        return clock;
    }
};
