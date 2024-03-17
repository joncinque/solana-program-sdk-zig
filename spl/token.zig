const std = @import("std");
const sol = @import("sol");
const bincode = @import("bincode");

const spl = @import("spl.zig");

const token = @This();

pub const Error = error{
    NotRentExempt,
    InsufficientFunds,
    InvalidMint,
    MintMismatch,
    OwnerMismatch,
    FixedSupply,
    AlreadyInUse,
    InvalidNumberOfProvidedSigners,
    InvalidNumberOfRequiredSigners,
    UninitializedState,
    NativeNotSupported,
    NonNativeHasBalance,
    InvalidInstruction,
    InvalidState,
    Overflow,
    AuthorityTypeNotSupported,
    MintCannotFreeze,
    AccountFrozen,
    MintDecimalsMismatch,
    NonNativeNotSupported,
};

pub fn getErrorFromCode(code: u32) (Error || error{Unknown})!void {
    inline for (@typeInfo(Error).ErrorSet.?, 0..) |err, i| {
        if (i == code) {
            return @field(token.Error, err.name);
        }
    }
    return error.Unknown;
}

pub const AuthorityType = enum(u8) {
    /// Authority to mint new tokens
    mint_tokens,
    /// Authority to freeze any account associated with the Mint
    freeze_account,
    /// Owner of a given token account
    account_owner,
    /// Authority to close a token account
    close_account,
};

pub const Instruction = union(enum(u8)) {
    /// Initializes a new mint and optionally deposits all the newly minted
    /// tokens in an account.
    ///
    /// The `InitializeMint` instruction requires no signers and MUST be
    /// included within the same Transaction as the system program's
    /// `CreateAccount` instruction that creates the account being initialized.
    /// Otherwise another party can acquire ownership of the uninitialized
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The mint to initialize.
    ///   1. `[]` Rent sysvar
    ///
    initialize_mint: struct {
        /// Number of base 10 digits to the right of the decimal place.
        decimals: u8,
        /// The authority/multisignature to mint tokens.
        mint_authority_id: sol.PublicKey,
        /// The freeze authority/multisignature of the mint.
        freeze_authority_id: ?sol.PublicKey,
    },
    /// Initializes a new account to hold tokens.  If this account is associated
    /// with the native mint then the token balance of the initialized account
    /// will be equal to the amount of SOL in the account. If this account is
    /// associated with another mint, that mint must be initialized before this
    /// command can succeed.
    ///
    /// The `InitializeAccount` instruction requires no signers and MUST be
    /// included within the same Transaction as the system program's
    /// `CreateAccount` instruction that creates the account being initialized.
    /// Otherwise another party can acquire ownership of the uninitialized
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]`  The account to initialize.
    ///   1. `[]` The mint this account will be associated with.
    ///   2. `[]` The new account's owner/multisignature.
    ///   3. `[]` Rent sysvar
    initialize_account: void,
    /// Initializes a multisignature account with N provided signers.
    ///
    /// Multisignature accounts can used in place of any single owner/delegate
    /// accounts in any token instruction that require an owner/delegate to be
    /// present.  The variant field represents the number of signers (M)
    /// required to validate this multisignature account.
    ///
    /// The `InitializeMultisig` instruction requires no signers and MUST be
    /// included within the same Transaction as the system program's
    /// `CreateAccount` instruction that creates the account being initialized.
    /// Otherwise another party can acquire ownership of the uninitialized
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The multisignature account to initialize.
    ///   1. `[]` Rent sysvar
    ///   2. ..2+N. `[]` The signer accounts, must equal to N where 1 <= N <=
    ///      11.
    initialize_multisig: struct {
        /// The number of signers (M) required to validate this multisignature
        /// account.
        m: u8,
    },
    /// Transfers tokens from one account to another either directly or via a
    /// delegate.  If this account is associated with the native mint then equal
    /// amounts of SOL and Tokens will be transferred to the destination
    /// account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[writable]` The destination account.
    ///   2. `[signer]` The source account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[writable]` The destination account.
    ///   2. `[]` The source account's multisignature owner/delegate.
    ///   3. ..3+M `[signer]` M signer accounts.
    transfer: struct {
        /// The amount of tokens to transfer.
        amount: u64,
    },
    /// Approves a delegate.  A delegate is given the authority over tokens on
    /// behalf of the source account's owner.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The delegate.
    ///   2. `[signer]` The source account owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The delegate.
    ///   2. `[]` The source account's multisignature owner.
    ///   3. ..3+M `[signer]` M signer accounts
    approve: struct {
        /// The amount of tokens the delegate is approved for.
        amount: u64,
    },
    /// Revokes the delegate's authority.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The source account.
    ///   1. `[signer]` The source account owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The source account's multisignature owner.
    ///   2. ..2+M `[signer]` M signer accounts
    revoke: void,
    /// Sets a new authority of a mint or account.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single authority
    ///   0. `[writable]` The mint or account to change the authority of.
    ///   1. `[signer]` The current authority of the mint or account.
    ///
    ///   * Multisignature authority
    ///   0. `[writable]` The mint or account to change the authority of.
    ///   1. `[]` The mint's or account's current multisignature authority.
    ///   2. ..2+M `[signer]` M signer accounts
    set_authority: struct {
        /// The type of authority to update.
        authority_type: AuthorityType,
        /// The new authority.
        new_authority_id: ?sol.PublicKey,
    },
    /// Mints new tokens to an account.  The native mint does not support
    /// minting.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[signer]` The mint's minting authority.
    ///
    ///   * Multisignature authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[]` The mint's multisignature mint-tokens authority.
    ///   3. ..3+M `[signer]` M signer accounts.
    mint_to: struct {
        /// The amount of new tokens to mint.
        amount: u64,
    },
    /// Burns tokens by removing them from an account.  `Burn` does not support
    /// accounts associated with the native mint, use `CloseAccount` instead.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[signer]` The account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[]` The account's multisignature owner/delegate.
    ///   3. ..3+M `[signer]` M signer accounts.
    burn: struct {
        /// The amount of tokens to burn.
        amount: u64,
    },
    /// Close an account by transferring all its SOL to the destination account.
    /// Non-native accounts may only be closed if its token amount is zero.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The account to close.
    ///   1. `[writable]` The destination account.
    ///   2. `[signer]` The account's owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The account to close.
    ///   1. `[writable]` The destination account.
    ///   2. `[]` The account's multisignature owner.
    ///   3. ..3+M `[signer]` M signer accounts.
    close_account: void,
    /// Freeze an Initialized account using the Mint's freeze_authority (if
    /// set).
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[signer]` The mint freeze authority.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[]` The mint's multisignature freeze authority.
    ///   3. ..3+M `[signer]` M signer accounts.
    freeze_account: void,
    /// Thaw a Frozen account using the Mint's freeze_authority (if set).
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[signer]` The mint freeze authority.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The account to freeze.
    ///   1. `[]` The token mint.
    ///   2. `[]` The mint's multisignature freeze authority.
    ///   3. ..3+M `[signer]` M signer accounts.
    thaw_account: void,
    /// Transfers tokens from one account to another either directly or via a
    /// delegate.  If this account is associated with the native mint then equal
    /// amounts of SOL and Tokens will be transferred to the destination
    /// account.
    ///
    /// This instruction differs from Transfer in that the token mint and
    /// decimals value is checked by the caller.  This may be useful when
    /// creating transactions offline or within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[writable]` The destination account.
    ///   3. `[signer]` The source account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[writable]` The destination account.
    ///   3. `[]` The source account's multisignature owner/delegate.
    ///   4. ..4+M `[signer]` M signer accounts.
    transfer_checked: struct {
        /// The amount of tokens to transfer.
        amount: u64,
        /// Expected number of base 10 digits to the right of the decimal place.
        decimals: u8,
    },
    /// Approves a delegate.  A delegate is given the authority over tokens on
    /// behalf of the source account's owner.
    ///
    /// This instruction differs from Approve in that the token mint and
    /// decimals value is checked by the caller.  This may be useful when
    /// creating transactions offline or within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[]` The delegate.
    ///   3. `[signer]` The source account owner.
    ///
    ///   * Multisignature owner
    ///   0. `[writable]` The source account.
    ///   1. `[]` The token mint.
    ///   2. `[]` The delegate.
    ///   3. `[]` The source account's multisignature owner.
    ///   4. ..4+M `[signer]` M signer accounts
    approve_checked: struct {
        /// The amount of tokens the delegate is approved for.
        amount: u64,
        /// Expected number of base 10 digits to the right of the decimal place.
        decimals: u8,
    },
    /// Mints new tokens to an account.  The native mint does not support
    /// minting.
    ///
    /// This instruction differs from MintTo in that the decimals value is
    /// checked by the caller.  This may be useful when creating transactions
    /// offline or within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[signer]` The mint's minting authority.
    ///
    ///   * Multisignature authority
    ///   0. `[writable]` The mint.
    ///   1. `[writable]` The account to mint tokens to.
    ///   2. `[]` The mint's multisignature mint-tokens authority.
    ///   3. ..3+M `[signer]` M signer accounts.
    mint_to_checked: struct {
        /// The amount of new tokens to mint.
        amount: u64,
        /// Expected number of base 10 digits to the right of the decimal place.
        decimals: u8,
    },
    /// Burns tokens by removing them from an account.  `BurnChecked` does not
    /// support accounts associated with the native mint, use `CloseAccount`
    /// instead.
    ///
    /// This instruction differs from Burn in that the decimals value is checked
    /// by the caller. This may be useful when creating transactions offline or
    /// within a hardware wallet.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   * Single owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[signer]` The account's owner/delegate.
    ///
    ///   * Multisignature owner/delegate
    ///   0. `[writable]` The account to burn from.
    ///   1. `[writable]` The token mint.
    ///   2. `[]` The account's multisignature owner/delegate.
    ///   3. ..3+M `[signer]` M signer accounts.
    burn_checked: struct {
        /// The amount of tokens to burn.
        amount: u64,
        /// Expected number of base 10 digits to the right of the decimal place.
        decimals: u8,
    },
    /// Like InitializeAccount, but the owner pubkey is passed via instruction data
    /// rather than the accounts list. This variant may be preferable when using
    /// Cross Program Invocation from an instruction that does not need the owner's
    /// `AccountInfo` otherwise.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]`  The account to initialize.
    ///   1. `[]` The mint this account will be associated with.
    ///   3. `[]` Rent sysvar
    initialize_account_2: struct {
        /// The new account's owner/multisignature.
        owner_id: sol.PublicKey,
    },
    /// Given a wrapped / native token account (a token account containing SOL)
    /// updates its amount field based on the account's underlying `lamports`.
    /// This is useful if a non-wrapped SOL account uses `system_instruction::transfer`
    /// to move lamports to a wrapped token account, and needs to have its token
    /// `amount` field updated.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]`  The native token account to sync with its underlying lamports.
    sync_native: void,
    /// Like InitializeAccount2, but does not require the Rent sysvar to be provided
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]`  The account to initialize.
    ///   1. `[]` The mint this account will be associated with.
    initialize_account_3: struct {
        /// The new account's owner/multisignature.
        owner_id: sol.PublicKey,
    },
    /// Like InitializeMultisig, but does not require the Rent sysvar to be provided
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The multisignature account to initialize.
    ///   1. ..1+N. `[]` The signer accounts, must equal to N where 1 <= N <=
    ///      11.
    initialize_multisig_2: struct {
        /// The number of signers (M) required to validate this multisignature
        /// account.
        m: u8,
    },
    /// Like InitializeMint, but does not require the Rent sysvar to be provided
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]` The mint to initialize.
    ///
    initialize_mint_2: struct {
        /// Number of base 10 digits to the right of the decimal place.
        decimals: u8,
        /// The authority/multisignature to mint tokens.
        mint_authority_id: sol.PublicKey,
        /// The freeze authority/multisignature of the mint.
        freeze_authority_id: ?sol.PublicKey,
    },
    /// Gets the required size of an account for the given mint as a little-endian
    /// `u64`.
    ///
    /// Return data can be fetched using `sol_get_return_data` and deserializing
    /// the return data as a little-endian `u64`.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[]` The mint to calculate for
    get_account_data_size: void,
    /// Initialize the Immutable Owner extension for the given token account
    ///
    /// Fails if the account has already been initialized, so must be called before
    /// `InitializeAccount`.
    ///
    /// No-ops in this version of the program, but is included for compatibility
    /// with the Associated Token Account program.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[writable]`  The account to initialize.
    ///
    /// Data expected by this instruction:
    ///   None
    initialize_immutable_owner: void,
    /// Convert an Amount of tokens to a UiAmount `string`, using the given mint.
    /// In this version of the program, the mint can only specify the number of decimals.
    ///
    /// Fails on an invalid mint.
    ///
    /// Return data can be fetched using `sol_get_return_data` and deserialized with
    /// `String::from_utf8`.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[]` The mint to calculate for
    amount_to_ui_amount: struct {
        /// The amount of tokens to reformat.
        amount: u64,
    },
    /// Convert a UiAmount of tokens to a little-endian `u64` raw Amount, using the given mint.
    /// In this version of the program, the mint can only specify the number of decimals.
    ///
    /// Return data can be fetched using `sol_get_return_data` and deserializing
    /// the return data as a little-endian `u64`.
    ///
    /// Accounts expected by this instruction:
    ///
    ///   0. `[]` The mint to calculate for
    ui_amount_to_amount: struct {
        /// The ui_amount of tokens to reformat.
        ui_amount: [*:0]u8,
    },
    // Any new variants also need to be added to program-2022 `TokenInstruction`, so that the
    // latter remains a superset of this instruction set. New variants also need to be added to
    // token/js/src/instructions/types.ts to maintain @solana/spl-token compatability
};

// 4 + 32 + 8 + 1 + 1 + 4 + 32

pub const Mint = struct {
    pub const len = 82;

    authority: bincode.Option(sol.PublicKey),
    supply: u64,
    decimals: u8,
    is_initialized: bool,
    freeze_authority: bincode.Option(sol.PublicKey),

    pub fn decode(bytes: []const u8) !token.Mint {
        return bincode.readFromSlice(undefined, token.Mint, bytes, .{});
    }

    pub fn writeTo(self: token.Mint, writer: anytype) !void {
        return bincode.write(writer, self, .{});
    }
};

pub const Account = struct {
    pub const len = 165;

    pub const State = enum(u8) {
        uninitialized,
        initialized,
        frozen,
    };

    mint_id: sol.PublicKey,
    owner: sol.PublicKey,
    amount: u64,
    delegate_id: bincode.Option(sol.PublicKey),
    state: token.Account.State,
    is_native: bincode.Option(u64),
    delegated_amount: u64,
    close_authority_id: bincode.Option(sol.PublicKey),

    pub fn decode(bytes: []const u8) !token.Account {
        return bincode.readFromSlice(undefined, token.Account, bytes, .{});
    }

    pub fn writeTo(self: token.Account, writer: anytype) !void {
        return bincode.write(writer, self, .{});
    }
};

pub const Multisig = struct {
    pub const len = 355;
    /// Minimum number of multisignature signers (min N)
    pub const min_signers = 1;
    /// Maximum number of multisignature signers (max N)
    pub const max_signers = 11;

    /// Number of signers required
    m: u8,
    /// Number of valid signers
    n: u8,
    /// Is `true` if this structure has been initialized
    is_initialized: bool,
    /// Signer public keys
    signers: [token.Multisig.max_signers]sol.PublicKey,
};

pub fn initializeMint(mint: sol.Account.Info, params: struct {
    mint_authority_id: sol.PublicKey,
    freeze_authority_id: ?sol.PublicKey,
    decimals: u8,
    rent: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction{
        .initialize_mint = .{
            .decimals = params.decimals,
            .mint_authority_id = params.mint_authority_id,
            .freeze_authority_id = params.freeze_authority_id,
        },
    }, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = mint.id, .is_writable = true, .is_signer = false },
            .{ .id = params.rent.id, .is_writable = false, .is_signer = false },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ mint, params.rent }, params.seeds);
}

pub fn initializeAccount(account: sol.Account.Info, params: struct {
    mint: sol.Account.Info,
    owner: sol.Account.Info,
    rent: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction.initialize_account, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.owner.id, .is_writable = false, .is_signer = false },
            .{ .id = params.rent.id, .is_writable = false, .is_signer = false },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ account, params.mint, params.owner, params.rent }, params.seeds);
}

pub fn transfer(params: struct {
    from: sol.Account.Info,
    to: sol.Account.Info,
    amount: u64,
    authority: union(enum) {
        single: sol.Account.Info,
        multiple: []const sol.Account.Info,
    },
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction{
        .transfer = .{ .amount = params.amount },
    }, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = params.from.id, .is_writable = true, .is_signer = false },
            .{ .id = params.to.id, .is_writable = true, .is_signer = false },
            .{ .id = params.authority.single.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ params.from, params.to, params.authority.single }, params.seeds);
}

pub fn setAuthority(mint_or_account: sol.Account.Info, params: struct {
    authority: union(enum) {
        single: sol.Account.Info,
        multiple: []const sol.Account.Info,
    },
    authority_type: AuthorityType,
    new_authority_id: ?sol.PublicKey,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction{
        .set_authority = .{
            .authority_type = params.authority_type,
            .new_authority_id = params.new_authority_id,
        },
    }, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = mint_or_account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.authority.single.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ mint_or_account, params.authority.single }, params.seeds);
}

pub fn burn(params: struct {
    account: sol.Account.Info,
    mint: sol.Account.Info,
    authority: union(enum) {
        single: sol.Account.Info,
        multiple: []const sol.Account.Info,
    },
    amount: u64,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction{
        .burn = .{
            .amount = params.amount,
        },
    }, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = params.account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = true, .is_signer = false },
            .{ .id = params.authority.single.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ params.account, params.mint, params.authority.single }, params.seeds);
}

pub fn mintTo(params: struct {
    mint: sol.Account.Info,
    account: sol.Account.Info,
    amount: u64,
    mint_authority: union(enum) {
        single: sol.Account.Info,
        multiple: []const sol.Account.Info,
    },
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction{
        .mint_to = .{
            .amount = params.amount,
        },
    }, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = params.mint.id, .is_writable = true, .is_signer = false },
            .{ .id = params.account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint_authority.single.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ params.mint, params.account, params.mint_authority.single }, params.seeds);
}

pub fn closeAccount(account: sol.Account.Info, params: struct {
    account_to_receive_remaining_tokens: sol.Account.Info,
    owner: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction.close_account, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.account_to_receive_remaining_tokens.id, .is_writable = true, .is_signer = false },
            .{ .id = params.owner.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ account, params.account_to_receive_remaining_tokens, params.owner }, params.seeds);
}

pub fn freezeAccount(account: sol.Account.Info, params: struct {
    mint: sol.Account.Info,
    freeze_authority: union(enum) {
        single: sol.Account.Info,
        multiple: []const sol.Account.Info,
    },
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try bincode.writeAlloc(sol.allocator, token.Instruction.freeze_account, .{});
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &spl.token_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = account.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.freeze_authority.single.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ account, params.mint, params.freeze_authority.single }, params.seeds);
}

test {
    std.testing.refAllDecls(@This());
}

test "token.Mint: decode" {
    _ = try token.Mint.decode(&.{ 1, 0, 0, 0, 152, 20, 133, 228, 144, 2, 178, 195, 30, 8, 250, 169, 148, 235, 43, 40, 87, 221, 245, 227, 234, 210, 0, 59, 91, 201, 36, 22, 115, 249, 197, 34, 128, 92, 74, 46, 88, 91, 240, 6, 9, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
}

test "token.Account: decode" {
    _ = try token.Account.decode(&.{ 38, 136, 199, 122, 42, 156, 154, 209, 115, 24, 105, 157, 203, 133, 179, 217, 162, 55, 98, 198, 231, 21, 107, 199, 248, 59, 48, 82, 149, 50, 147, 242, 137, 3, 79, 28, 13, 227, 40, 160, 41, 42, 170, 226, 227, 192, 156, 176, 67, 103, 166, 39, 95, 238, 193, 178, 126, 0, 146, 162, 23, 67, 18, 159, 232, 115, 60, 12, 252, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
}
