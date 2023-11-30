const std = @import("std");
const bincode = @import("bincode");

const Account = @import("account.zig").Account;
const allocator = @import("allocator.zig");
const ix = @import("instruction.zig");
const PublicKey = @import("public_key.zig").PublicKey;

const SystemProgram = @This();
pub const id = PublicKey.comptimeFromBase58("11111111111111111111111111111111");

pub fn createAccount(account: Account.Info, params: struct {
    payer: Account.Info,
    lamports: u64,
    space: u64,
    owner_id: PublicKey,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(allocator, SystemProgram.Instruction{
        .create_account = .{
            .lamports = params.lamports,
            .space = params.space,
            .owner_id = params.owner_id,
        },
    }, .{});
    defer allocator.free(data);

    const instruction = ix.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.payer.id, .is_writable = true, .is_signer = true },
            .{ .id = account.id, .is_writable = true, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ params.payer, account }, params.seeds);
}

pub fn transfer(params: struct {
    from: Account.Info,
    to: Account.Info,
    lamports: u64,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(allocator, SystemProgram.Instruction{
        .transfer = .{ .lamports = params.lamports },
    }, .{});
    defer allocator.free(data);

    const instruction = ix.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = params.from.id, .is_writable = true, .is_signer = true },
            .{ .id = params.to.id, .is_writable = true, .is_signer = false },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ params.from, params.to }, params.seeds);
}

pub fn allocate(account: Account.Info, space: u64, params: struct {
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(allocator, SystemProgram.Instruction{
        .allocate = .{ .space = space },
    }, .{});
    defer allocator.free(data);

    const instruction = ix.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = account.id, .is_writable = true, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{account}, params.seeds);
}

pub fn assign(account: Account.Info, owner_id: PublicKey, params: struct {
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(allocator, SystemProgram.Instruction{
        .assign = .{ .owner_id = owner_id },
    }, .{});
    defer allocator.free(data);

    const instruction = ix.Instruction.from(.{
        .program_id = &id,
        .accounts = &[_]Account.Param{
            .{ .id = account.id, .is_writable = true, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{account}, params.seeds);
}

pub const Instruction = union(enum(u32)) {
    /// Create a new account
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE, SIGNER]` New account
    create_account: struct {
        /// Number of lamports to transfer to the new account
        lamports: u64,
        /// Number of bytes of memory to allocate
        space: u64,
        /// Address of program that will own the new account
        owner_id: PublicKey,
    },
    /// Assign account to a program
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Assigned account public key
    assign: struct {
        /// Owner program account
        owner_id: PublicKey,
    },
    /// Transfer lamports
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE]` Recipient account
    transfer: struct {
        lamports: u64,
    },
    /// Create a new account at an address derived from a base public key and a seed
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` Funding account
    ///   1. `[WRITE]` Created account
    ///   2. `[SIGNER]` (optional) Base account; the account matching the base PublicKey below must be
    ///                          provided as a signer, but may be the same as the funding account
    ///                          and provided as account 0
    create_account_with_seed: struct {
        /// Base public key
        base: PublicKey,
        /// String of ASCII chars, no longer than `PublicKey.max_seed_length`
        seed: []const u8,
        /// Number of lamports to transfer to the new account
        lamports: u64,
        /// Number of bytes of memory to allocate
        space: u64,
        /// Owner program account address
        owner_id: PublicKey,
    },
    /// Consumes a stored nonce, replacing it with a successor
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[]` RecentBlockhashes sysvar
    ///   2. `[SIGNER]` Nonce authority
    advance_nonce_account: void,
    /// Withdraw funds from a nonce account
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[WRITE]` Recipient account
    ///   2. `[]` RecentBlockhashes sysvar
    ///   3. `[]` Rent sysvar
    ///   4. `[SIGNER]` Nonce authority
    ///
    /// The `u64` parameter is the lamports to withdraw, which must leave the
    /// account balance above the rent exempt reserve or at zero.
    withdraw_nonce_account: u64,
    /// Drive state of Uninitialized nonce account to Initialized, setting the nonce value
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[]` RecentBlockhashes sysvar
    ///   2. `[]` Rent sysvar
    ///
    /// The `PublicKey` parameter specifies the entity authorized to execute nonce
    /// instruction on the account
    ///
    /// No signatures are required to execute this instruction, enabling derived
    /// nonce account addresses
    initialize_nonce_account: PublicKey,
    /// Change the entity authorized to execute nonce instructions on the account
    ///
    /// # Account references
    ///   0. `[WRITE]` Nonce account
    ///   1. `[SIGNER]` Nonce authority
    ///
    /// The `PublicKey` parameter identifies the entity to authorize
    authorize_nonce_account: PublicKey,
    /// Allocate space in a (possibly new) account without funding
    ///
    /// # Account references
    ///   0. `[WRITE, SIGNER]` New account
    allocate: struct {
        /// Number of bytes of memory to allocate
        space: u64,
    },
    /// Allocate space for and assign an account at an address
    ///    derived from a base public key and a seed
    ///
    /// # Account references
    ///   0. `[WRITE]` Allocated account
    ///   1. `[SIGNER]` Base account
    allocate_with_seed: struct {
        /// Base public key
        base: PublicKey,
        /// String of ASCII chars, no longer than `PublicKey.max_seed_len`
        seed: []const u8,
        /// Number of bytes of memory to allocate
        space: u64,
        /// Owner program account
        owner_id: PublicKey,
    },
    /// Assign account to a program based on a seed
    ///
    /// # Account references
    ///   0. `[WRITE]` Assigned account
    ///   1. `[SIGNER]` Base account
    assign_with_seed: struct {
        /// Base public key
        base: PublicKey,
        /// String of ASCII chars, no longer than `PublicKey.max_Seed_len`
        seed: []const u8,
        /// Owner program account
        owner_id: PublicKey,
    },
    /// Transfer lamports from a derived address
    ///
    /// # Account references
    ///   0. `[WRITE]` Funding account
    ///   1. `[SIGNER]` Base for funding account
    ///   2. `[WRITE]` Recipient account
    transfer_with_seed: struct {
        /// Amount to transfer
        lamports: u64,
        /// Seed to use to derive the funding accout address
        from_seed: []const u8,
        /// Owner to use to derive the funding account address
        from_owner: PublicKey,
    },
};

test "SystemProgram.Instruction: serialize and deserialize" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    inline for (.{ .{}, bincode.Params.legacy, bincode.Params.standard }) |params| {
        inline for (.{
            SystemProgram.Instruction{
                .create_account = .{
                    .lamports = 1586880,
                    .space = 100,
                    .owner_id = id,
                },
            },
        }) |payload| {
            try bincode.write(buffer.writer(), payload, params);
            var stream = std.io.fixedBufferStream(buffer.items);
            try std.testing.expectEqual(payload, try bincode.read(std.testing.allocator, @TypeOf(payload), stream.reader(), params));
            buffer.clearRetainingCapacity();
        }
    }
}
