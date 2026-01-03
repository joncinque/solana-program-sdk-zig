const std = @import("std");

/// Builtin return values occupy the upper 32 bits
pub const BUILTIN_BIT_SHIFT: u6 = 32;

fn toBuiltin(comptime error_code: u64) u64 {
    return error_code << BUILTIN_BIT_SHIFT;
}

/// Reasons the program may fail
/// Matches the Solana SDK ProgramError enum values
pub const ProgramError = enum(u64) {
    /// Custom program error with code 0
    CustomZero = toBuiltin(1),
    /// The arguments provided to a program instruction were invalid
    InvalidArgument = toBuiltin(2),
    /// An instruction's data contents was invalid
    InvalidInstructionData = toBuiltin(3),
    /// An account's data contents was invalid
    InvalidAccountData = toBuiltin(4),
    /// An account's data was too small
    AccountDataTooSmall = toBuiltin(5),
    /// An account's balance was too small to complete the instruction
    InsufficientFunds = toBuiltin(6),
    /// The account did not have the expected program id
    IncorrectProgramId = toBuiltin(7),
    /// A signature was required but not found
    MissingRequiredSignature = toBuiltin(8),
    /// An initialize instruction was sent to an account that has already been initialized
    AccountAlreadyInitialized = toBuiltin(9),
    /// An attempt to operate on an account that hasn't been initialized
    UninitializedAccount = toBuiltin(10),
    /// The instruction expected additional account keys
    NotEnoughAccountKeys = toBuiltin(11),
    /// Failed to borrow a reference to account data, already borrowed
    AccountBorrowFailed = toBuiltin(12),
    /// Length of the seed is too long for address generation
    MaxSeedLengthExceeded = toBuiltin(13),
    /// Provided seeds do not result in a valid address
    InvalidSeeds = toBuiltin(14),
    /// IO Error
    BorshIoError = toBuiltin(15),
    /// An account does not have enough lamports to be rent-exempt
    AccountNotRentExempt = toBuiltin(16),
    /// Unsupported sysvar
    UnsupportedSysvar = toBuiltin(17),
    /// Provided owner is not allowed
    IllegalOwner = toBuiltin(18),
    /// Accounts data allocations exceeded the maximum allowed per transaction
    MaxAccountsDataAllocationsExceeded = toBuiltin(19),
    /// Account data reallocation was invalid
    InvalidRealloc = toBuiltin(20),
    /// Instruction trace length exceeded the maximum allowed per transaction
    MaxInstructionTraceLengthExceeded = toBuiltin(21),
    /// Builtin programs must consume compute units
    BuiltinProgramsMustConsumeComputeUnits = toBuiltin(22),
    /// Invalid account owner
    InvalidAccountOwner = toBuiltin(23),
    /// Program arithmetic overflowed
    ArithmeticOverflow = toBuiltin(24),
    /// Account is immutable
    Immutable = toBuiltin(25),
    /// Incorrect authority provided
    IncorrectAuthority = toBuiltin(26),

    // Non-builtin errors that can be used with _
    _,

    /// Convert error to u64 for return from entrypoint
    pub fn toU64(self: ProgramError) u64 {
        return @intFromEnum(self);
    }

    /// Create a custom error from a u32 error code
    /// Custom errors occupy the lower 32 bits
    pub fn custom(error_code: u32) ProgramError {
        if (error_code == 0) {
            return .CustomZero;
        }
        return @enumFromInt(error_code);
    }

    /// Get the custom error code if this is a custom error
    /// Returns null for builtin errors
    pub fn getCustomCode(self: ProgramError) ?u32 {
        const val = @intFromEnum(self);
        if (val == @intFromEnum(ProgramError.CustomZero)) {
            return 0;
        }
        // If value is less than BUILTIN threshold, it's a custom error
        if (val < toBuiltin(1)) {
            return @truncate(val);
        }
        return null;
    }

    /// Check if this is a builtin error
    pub fn isBuiltin(self: ProgramError) bool {
        return self.getCustomCode() == null;
    }

    /// Get a human-readable description of the error
    pub fn toString(self: ProgramError) []const u8 {
        return switch (self) {
            .CustomZero => "Custom program error: 0x0",
            .InvalidArgument => "The arguments provided to a program instruction were invalid",
            .InvalidInstructionData => "An instruction's data contents was invalid",
            .InvalidAccountData => "An account's data contents was invalid",
            .AccountDataTooSmall => "An account's data was too small",
            .InsufficientFunds => "An account's balance was too small to complete the instruction",
            .IncorrectProgramId => "The account did not have the expected program id",
            .MissingRequiredSignature => "A signature was required but not found",
            .AccountAlreadyInitialized => "An initialize instruction was sent to an account that has already been initialized",
            .UninitializedAccount => "An attempt to operate on an account that hasn't been initialized",
            .NotEnoughAccountKeys => "The instruction expected additional account keys",
            .AccountBorrowFailed => "Failed to borrow a reference to account data, already borrowed",
            .MaxSeedLengthExceeded => "Length of the seed is too long for address generation",
            .InvalidSeeds => "Provided seeds do not result in a valid address",
            .BorshIoError => "IO Error",
            .AccountNotRentExempt => "An account does not have enough lamports to be rent-exempt",
            .UnsupportedSysvar => "Unsupported sysvar",
            .IllegalOwner => "Provided owner is not allowed",
            .MaxAccountsDataAllocationsExceeded => "Accounts data allocations exceeded the maximum allowed per transaction",
            .InvalidRealloc => "Account data reallocation was invalid",
            .MaxInstructionTraceLengthExceeded => "Instruction trace length exceeded the maximum allowed per transaction",
            .BuiltinProgramsMustConsumeComputeUnits => "Builtin programs must consume compute units",
            .InvalidAccountOwner => "Invalid account owner",
            .ArithmeticOverflow => "Program arithmetic overflowed",
            .Immutable => "Account is immutable",
            .IncorrectAuthority => "Incorrect authority provided",
            _ => "Custom program error",
        };
    }

    /// Create ProgramError from a u64 value (e.g., from runtime)
    pub fn fromU64(value: u64) ProgramError {
        return @enumFromInt(value);
    }
};

test "ProgramError values match Rust SDK" {
    // Verify builtin error values match Rust SDK
    try std.testing.expectEqual(@as(u64, 1 << 32), @intFromEnum(ProgramError.CustomZero));
    try std.testing.expectEqual(@as(u64, 2 << 32), @intFromEnum(ProgramError.InvalidArgument));
    try std.testing.expectEqual(@as(u64, 3 << 32), @intFromEnum(ProgramError.InvalidInstructionData));
    try std.testing.expectEqual(@as(u64, 4 << 32), @intFromEnum(ProgramError.InvalidAccountData));
    try std.testing.expectEqual(@as(u64, 5 << 32), @intFromEnum(ProgramError.AccountDataTooSmall));
    try std.testing.expectEqual(@as(u64, 6 << 32), @intFromEnum(ProgramError.InsufficientFunds));
    try std.testing.expectEqual(@as(u64, 7 << 32), @intFromEnum(ProgramError.IncorrectProgramId));
    try std.testing.expectEqual(@as(u64, 26 << 32), @intFromEnum(ProgramError.IncorrectAuthority));
}

test "custom errors" {
    // Custom error with code 0 should map to CustomZero
    const err0 = ProgramError.custom(0);
    try std.testing.expectEqual(ProgramError.CustomZero, err0);
    try std.testing.expectEqual(@as(?u32, 0), err0.getCustomCode());

    // Custom error with non-zero code
    const err42 = ProgramError.custom(42);
    try std.testing.expectEqual(@as(u64, 42), err42.toU64());
    try std.testing.expectEqual(@as(?u32, 42), err42.getCustomCode());

    // Builtin errors should return null for getCustomCode
    try std.testing.expectEqual(@as(?u32, null), ProgramError.InvalidArgument.getCustomCode());
}
