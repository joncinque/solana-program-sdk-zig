const std = @import("std");
const bitcoin = @import("base58.zig").bitcoin;

pub fn generateProgramKeypair(b: *std.build.Builder, lib: *std.build.LibExeObjStep) !void {
    const path = b.fmt("{s}-keypair.json", .{lib.out_filename[0 .. lib.out_filename.len - std.fs.path.extension(lib.out_filename).len]});
    const absolute_path = b.getInstallPath(.lib, path);

    if (std.fs.openFileAbsolute(absolute_path, .{})) |keypair_file| {
        const keypair_json = try keypair_file.readToEndAlloc(b.allocator, 1 * 1024 * 1024);
        const parsed_keypair = try std.json.parseFromSlice([std.crypto.sign.Ed25519.SecretKey.encoded_length]u8, b.allocator, keypair_json, .{});
        defer parsed_keypair.deinit();
        const keypair_secret = parsed_keypair.value;

        const keypair = try std.crypto.sign.Ed25519.KeyPair.fromSecretKey(try std.crypto.sign.Ed25519.SecretKey.fromBytes(keypair_secret));

        var program_id_buffer: [bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        const program_id = bitcoin.encode(&program_id_buffer, &keypair.public_key.bytes);

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

        var program_id_buffer: [bitcoin.getEncodedLengthUpperBound(std.crypto.sign.Ed25519.PublicKey.encoded_length)]u8 = undefined;
        const program_id = bitcoin.encode(&program_id_buffer, &program_keypair.public_key.bytes);

        std.debug.print("Program ID: {s}\n", .{program_id});
    }
}

