const sol = @import("sol.zig");

pub const Rent = struct {
    pub const id = sol.rent_id;

    /// Default rental rate in lamports/byte-year based on:
    /// - 10^9 lamports per SOL
    /// - $1 per SOL
    /// - $0.01 per megabyte day
    /// - $3.65 per megabyte year
    pub const default_lamports_per_byte_year: u64 = 1_000_000_000 / 100 * 365 / (1024 * 1024);

    /// Default amount of time (in years) the balance has to include rent for.
    pub const default_exemption_threshold: f64 = 2.0;

    /// Default percentage of rent to burn (valid values are 0 to 100).
    pub const default_burn_percent: u8 = 50;

    /// Account storage overhead for calculation of base rent.
    pub const account_storage_overhead: u64 = 128;

    pub const Data = extern struct {
        lamports_per_byte_year: u64 = Rent.default_lamports_per_byte_year,
        exemption_threshold: f64 = Rent.default_exemption_threshold,
        burn_percent: u8 = Rent.default_burn_percent,

        pub fn getAmountBurned(self: Rent.Data, rent_collected: u64) struct { burned: u64, remaining: u64 } {
            const burned = (rent_collected * @as(u64, self.burn_percent)) / 100;
            return .{ .burned = burned, .remaining = rent_collected - burned };
        }

        pub fn getAmountDue(self: Rent.Data, balance: u64, data_len: usize, years_elapsed: f64) ?u64 {
            if (self.isExempt(balance, data_len)) return null;
            const total_data_len: u64 = Rent.account_storage_overhead + data_len;
            return @intFromFloat(@as(f64, @floatFromInt(total_data_len * self.lamports_per_byte_year)) * years_elapsed);
        }

        pub fn isExempt(self: Rent.Data, balance: u64, data_len: usize) bool {
            return balance >= self.getMinimumBalance(data_len);
        }

        pub fn getMinimumBalance(self: Rent.Data, data_len: usize) u64 {
            const total_data_len: u64 = Rent.account_storage_overhead + data_len;
            return @intFromFloat(@as(f64, @floatFromInt(total_data_len * self.lamports_per_byte_year)) * self.exemption_threshold);
        }
    };

    pub fn get() !Rent.Data {
        var rent: Rent.Data = undefined;
        if (sol.is_bpf_program) {
            const Syscall = struct {
                extern fn sol_get_rent_sysvar(ptr: *Rent.Data) callconv(.C) u64;
            };
            const result = Syscall.sol_get_rent_sysvar(&rent);
            if (result != 0) {
                sol.print("failed to get rent sysvar: error code {}", .{result});
                return error.Unexpected;
            }
        }
        return rent;
    }
};
