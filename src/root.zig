const std = @import("std");

pub const public_key = @import("public_key.zig");
pub const account = @import("account.zig");
pub const instruction = @import("instruction.zig");
pub const allocator = @import("allocator.zig");
pub const context = @import("context.zig");
pub const clock = @import("clock.zig");
pub const rent = @import("rent.zig");
pub const log = @import("log.zig");
pub const hash = @import("hash.zig");

pub const blake3 = @import("blake3.zig");
pub const slot_hashes = @import("slot_hashes.zig");

pub const bpf = @import("bpf.zig");

pub const native_loader_id = public_key.PublicKey.comptimeFromBase58("NativeLoader1111111111111111111111111111111");
pub const incinerator_id = public_key.PublicKey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");

pub const sysvar_id = public_key.PublicKey.comptimeFromBase58("Sysvar1111111111111111111111111111111111111");
pub const instructions_id = public_key.PublicKey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

pub const ed25519_program_id = public_key.PublicKey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");
pub const secp256k1_program_id = public_key.PublicKey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");

pub const lamports_per_sol = 1_000_000_000;

test {
    std.testing.refAllDecls(@This());
}
