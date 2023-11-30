const std = @import("std");

pub fn base58Module(b: *std.build.Builder, comptime base_dir: []const u8) std.build.ModuleDependency {
    return .{ .name = "base58", .module = b.createModule(.{
        .source_file = .{ .path = base_dir ++ "base58/base58.zig" },
    }) };
}

fn dependentSolModules(b: *std.build.Builder, comptime base_dir: []const u8, base58: std.build.ModuleDependency) [5]std.build.ModuleDependency {
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
        bincode,
        borsh,
        sol,
        spl,
        metaplex,
    };
}

pub fn allSolModules(b: *std.build.Builder, comptime base_dir: []const u8) [6]std.build.ModuleDependency {
    const base58 = base58Module(b, base_dir);
    const dependent_modules = dependentSolModules(b, base_dir, base58);

    return .{base58} ++ dependent_modules;
}

fn buildProgramWithTarget(b: *std.build.Builder, target: std.zig.CrossTarget) !void {
    const base58 = base58Module(b, "");
    const sol_modules = dependentSolModules(b, "", base58);

    const optimize = .ReleaseSmall;
    const program = b.addSharedLibrary(.{
        .name = "main",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .target = target,
    });
    program.addModule(base58.name, base58.module);
    inline for (sol_modules) |package| {
        program.addModule(package.name, package.module);
    }
    b.installArtifact(program);

    try linkSolanaProgram(b, program);
    try generateProgramKeypair(b, program, base58);
}

pub fn buildProgramV2(b: *std.build.Builder) !void {
    const sbfv2 = std.Target.sbf.cpu.sbfv2;
    const target = .{
        .cpu_arch = .sbf,
        .cpu_model = .{
            .explicit = &sbfv2,
        },
        .os_tag = .solana,
        .cpu_features_add = sbfv2.features,
    };

    buildProgramWithTarget(b, target);
}

pub fn buildProgram(b: *std.build.Builder) !void {
    const target = .{
        .cpu_arch = .bpfel,
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.bpf.featureSet(&.{.solana}),
    };

    buildProgramWithTarget(b, target);
}

pub fn generateProgramKeypair(b: *std.build.Builder, lib: *std.build.LibExeObjStep, base58: std.build.ModuleDependency) !void {
    const path = b.fmt("{s}-keypair.json", .{lib.out_filename[0 .. lib.out_filename.len - std.fs.path.extension(lib.out_filename).len]});
    const absolute_path = b.getInstallPath(.lib, path);

    if (std.fs.openFileAbsolute(absolute_path, .{})) |keypair_file| {
        const keypair_json = try keypair_file.readToEndAlloc(b.allocator, 1 * 1024 * 1024);
        const parsed_keypair = try std.json.parseFromSlice([std.crypto.sign.Ed25519.SecretKey.encoded_length]u8, b.allocator, keypair_json, .{});
        defer parsed_keypair.deinit();
        const keypair_secret = parsed_keypair.value;

        const keypair = try std.crypto.sign.Ed25519.KeyPair.fromSecretKey(try std.crypto.sign.Ed25519.SecretKey.fromBytes(keypair_secret));

        var program_id_buffer: [base58.module.bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        const program_id = base58.module.bitcoin.encode(&program_id_buffer, &keypair.public_key.bytes);

        std.debug.print("Program ID: {s}\n", .{program_id});
    } else |err| {
        if (err != std.fs.File.OpenError.FileNotFound) {
            return err;
        }

        const program_keypair = try std.crypto.sign.Ed25519.KeyPair.create(null);

        var keypair_json = std.ArrayList(u8).init(b.allocator);
        try std.json.stringify(program_keypair.secret_key.bytes, .{}, keypair_json.writer());

        const keypair = b.addWriteFile(path, keypair_json.items);
        b.getInstallStep().dependOn(&keypair.step);

        const install_keypair = b.addInstallLibFile(keypair.files.items[0].getPath(), path);
        b.getInstallStep().dependOn(&install_keypair.step);

        var program_id_buffer: [base58.module.bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        const program_id = base58.module.bitcoin.encode(&program_id_buffer, &program_keypair.public_key.bytes);

        std.debug.print("Program ID: {s}\n", .{program_id});
    }
}

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
