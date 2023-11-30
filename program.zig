const std = @import("std");

pub fn allSolModules(b: *std.build.Builder, comptime base_dir: []const u8) [6]std.build.ModuleDependency {
    const base58 = .{ .name = "base58", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "base58/base58.zig" },
    }) };

    const bincode = .{ .name = "bincode", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "bincode/bincode.zig" },
    }) };

    const borsh = .{ .name = "borsh", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "borsh/borsh.zig" },
    }) };

    const sol = .{ .name = "sol", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "sol.zig" },
        .dependencies = &.{
            base58,
            bincode,
        },
    }) };

    const spl = .{ .name = "spl", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "spl/spl.zig" },
        .dependencies = &.{
            sol,
            bincode,
        },
    }) };

    const metaplex = .{ .name = "metaplex", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "metaplex/metaplex.zig" },
        .dependencies = &.{
            sol,
            borsh,
        },
    }) };

    return [_]std.build.ModuleDependency{
        base58,
        bincode,
        borsh,
        sol,
        spl,
        metaplex,
    };
}

pub fn buildProgram(b: *std.build.Builder, program: *std.build.LibExeObjStep, comptime base_dir: []const u8) !void {
    const sol_modules = allSolModules(b, base_dir);

    inline for (sol_modules) |package| {
        program.addModule(package.name, package.module);
    }
    b.installArtifact(program);

    try linkSolanaProgram(b, program);
    //try generateProgramKeypair(b, program);
}

pub const sbf_target: std.zig.CrossTarget = .{
    .cpu_arch = .sbf,
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.featureSet(&.{.solana}),
};

pub const sbfv2_target: std.zig.CrossTarget = .{
    .cpu_arch = .sbf,
    .cpu_model = .{
        .explicit = &std.Target.sbf.cpu.sbfv2,
    },
    .os_tag = .solana,
    .cpu_features_add = std.Target.sbf.cpu.sbfv2.features,
};

pub const bpf_target: std.zig.CrossTarget = .{
    .cpu_arch = .bpfel,
    .os_tag = .freestanding,
    .cpu_features_add = std.Target.bpf.featureSet(&.{.solana}),
};

// TODO how to use base58 within the build without `file exists in multiple modules`?
// it might be easiest to create a `solana-keygen`-style executable in `base58`
// and call that from here
//pub fn generateProgramKeypair(b: *std.build.Builder, lib: *std.build.LibExeObjStep) !void {
    //const bitcoin = @import("base58/base58.zig").bitcoin;
    //const path = b.fmt("{s}-keypair.json", .{lib.out_filename[0 .. lib.out_filename.len - std.fs.path.extension(lib.out_filename).len]});
    //const absolute_path = b.getInstallPath(.lib, path);

    //if (std.fs.openFileAbsolute(absolute_path, .{})) |keypair_file| {
        //const keypair_json = try keypair_file.readToEndAlloc(b.allocator, 1 * 1024 * 1024);
        //const parsed_keypair = try std.json.parseFromSlice([std.crypto.sign.Ed25519.SecretKey.encoded_length]u8, b.allocator, keypair_json, .{});
        //defer parsed_keypair.deinit();
        //const keypair_secret = parsed_keypair.value;

        //const keypair = try std.crypto.sign.Ed25519.KeyPair.fromSecretKey(try std.crypto.sign.Ed25519.SecretKey.fromBytes(keypair_secret));

        //var program_id_buffer: [bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        //const program_id = bitcoin.encode(&program_id_buffer, &keypair.public_key.bytes);

        //std.debug.print("Program ID: {s}\n", .{program_id});
    //} else |err| {
        //if (err != std.fs.File.OpenError.FileNotFound) {
            //return err;
        //}

        //const program_keypair = try std.crypto.sign.Ed25519.KeyPair.create(null);

        //var keypair_json = std.ArrayList(u8).init(b.allocator);
        //try std.json.stringify(program_keypair.secret_key.bytes, .{}, keypair_json.writer());

        //const keypair = b.addWriteFile(path, keypair_json.items);
        //b.getInstallStep().dependOn(&keypair.step);

        //const install_keypair = b.addInstallLibFile(keypair.files.items[0].getPath(), path);
        //b.getInstallStep().dependOn(&install_keypair.step);

        //var program_id_buffer: [bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        //const program_id = bitcoin.encode(&program_id_buffer, &program_keypair.public_key.bytes);

        //std.debug.print("Program ID: {s}\n", .{program_id});
    //}
//}

pub fn linkSolanaProgram(b: *std.build.Builder, lib: *std.build.LibExeObjStep) !void {
    const linker_script = b.addWriteFile("bpf.ld",
        \\PHDRS
        \\{
        \\text PT_LOAD  ;
        \\rodata PT_LOAD ;
        \\dynamic PT_DYNAMIC ;
        \\}
        \\
        \\SECTIONS
        \\{
        \\. = SIZEOF_HEADERS;
        \\.text : { *(.text*) } :text
        \\.rodata : { *(.rodata*) } :rodata
        \\.data.rel.ro : { *(.data.rel.ro*) } :rodata
        \\.dynamic : { *(.dynamic) } :dynamic
        \\}
    );

    lib.step.dependOn(&linker_script.step);

    lib.stack_size = 4096;
    lib.linker_script = linker_script.files.items[0].getPath();
    lib.entry_symbol_name = "entrypoint";
    lib.force_pic = true;
    lib.strip = true;
    lib.link_z_notext = true;
}
