const std = @import("std");
const builtin = @import("builtin");
const PublicKey = @import("public_key.zig").PublicKey;
const syscalls = @import("syscalls.zig");

pub const bpf_loader_deprecated_program_id = PublicKey.comptimeFromBase58("BPFLoader1111111111111111111111111111111111");
pub const bpf_loader_program_id = PublicKey.comptimeFromBase58("BPFLoader2111111111111111111111111111111111");
pub const bpf_upgradeable_loader_program_id = PublicKey.comptimeFromBase58("BPFLoaderUpgradeab1e11111111111111111111111");

pub const UpgradeableLoaderState = union(enum(u32)) {
    pub const ProgramData = struct {
        slot: u64,
        upgrade_authority_id: ?PublicKey,
    };

    uninitialized: void,
    buffer: struct {
        authority_id: ?PublicKey,
    },
    program: struct {
        program_data_id: PublicKey,
    },
    program_data: ProgramData,
};

pub fn getUpgradeableLoaderProgramDataId(program_id: PublicKey) !PublicKey {
    const pda = try PublicKey.findProgramAddress(.{program_id}, bpf_upgradeable_loader_program_id);
    return pda.address;
}

/// Check if we're running as a BPF program
/// Uses the new detection method compatible with standard Zig
pub const is_bpf_program = syscalls.is_bpf_program;
