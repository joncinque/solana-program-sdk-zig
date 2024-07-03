const std = @import("std");

const sol = @This();

pub usingnamespace @import("public_key.zig");
pub usingnamespace @import("account.zig");
pub usingnamespace @import("instruction.zig");
pub usingnamespace @import("allocator.zig");
pub usingnamespace @import("context.zig");
pub usingnamespace @import("clock.zig");
pub usingnamespace @import("rent.zig");
pub usingnamespace @import("log.zig");
pub usingnamespace @import("hash.zig");

pub const blake3 = @import("blake3.zig");
//pub const system_program = @import("system_program.zig");
pub const slot_hashes = @import("slot_hashes.zig");

pub const bpf = @import("bpf.zig");

pub const native_loader_id = sol.PublicKey.comptimeFromBase58("NativeLoader1111111111111111111111111111111");
pub const incinerator_id = sol.PublicKey.comptimeFromBase58("1nc1nerator11111111111111111111111111111111");

pub const sysvar_id = sol.PublicKey.comptimeFromBase58("Sysvar1111111111111111111111111111111111111");
pub const instructions_id = sol.PublicKey.comptimeFromBase58("Sysvar1nstructions1111111111111111111111111");

pub const ed25519_program_id = sol.PublicKey.comptimeFromBase58("Ed25519SigVerify111111111111111111111111111");
pub const secp256k1_program_id = sol.PublicKey.comptimeFromBase58("KeccakSecp256k11111111111111111111111111111");

pub const lamports_per_sol = 1_000_000_000;

test {
    std.testing.refAllDecls(@This());
}
