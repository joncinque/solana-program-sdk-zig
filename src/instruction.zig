const std = @import("std");
const Account = @import("account.zig").Account;
const PublicKey = @import("public_key.zig").PublicKey;
const bpf = @import("bpf.zig");

pub const Instruction = extern struct {
    program_id: *const PublicKey,
    accounts: [*]const Account.Param,
    accounts_len: usize,
    data: [*]const u8,
    data_len: usize,

    extern fn sol_invoke_signed_c(
        instruction: *const Instruction,
        account_infos: ?[*]const Account.Info,
        account_infos_len: usize,
        signer_seeds: ?[*]const []const []const u8,
        signer_seeds_len: usize,
    ) callconv(.C) u64;

    pub fn from(params: struct {
        program_id: *const PublicKey,
        accounts: []const Account.Param,
        data: []const u8,
    }) Instruction {
        return .{
            .program_id = params.program_id,
            .accounts = params.accounts.ptr,
            .accounts_len = params.accounts.len,
            .data = params.data.ptr,
            .data_len = params.data.len,
        };
    }

    pub fn invoke(self: *const Instruction, accounts: []const Account.Info) !void {
        if (bpf.is_bpf_program) {
            return switch (sol_invoke_signed_c(self, accounts.ptr, accounts.len, null, 0)) {
                0 => {},
                else => error.CrossProgramInvocationFailed,
            };
        }
        return error.CrossProgramInvocationFailed;
    }

    pub fn invokeSigned(self: *const Instruction, accounts: []const Account.Info, signer_seeds: []const []const []const u8) !void {
        if (bpf.is_bpf_program) {
            return switch (sol_invoke_signed_c(self, accounts.ptr, accounts.len, signer_seeds.ptr, signer_seeds.len)) {
                0 => {},
                else => error.CrossProgramInvocationFailed,
            };
        }
        return error.CrossProgramInvocationFailed;
    }
};
