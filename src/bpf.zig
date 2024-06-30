const std = @import("std");
const builtin = @import("builtin");
const PublicKey = @import("public_key.zig").PublicKey;

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

pub const is_bpf_program = !builtin.is_test and
    ((builtin.os.tag == .freestanding and
    builtin.cpu.arch == .bpfel and
    std.Target.bpf.featureSetHas(builtin.cpu.features, .solana)) or
    (builtin.cpu.arch == .sbf));
