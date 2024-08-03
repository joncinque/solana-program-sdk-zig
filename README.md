# solana-zig-sdk

Write Solana on-chain programs in Zig!

If you want a more complete program example, please see the
[`solana-helloworld-zig` repo](https://github.com/joncinque/solana-helloworld-zig),
which also provides tests and a CLI.

## Other Zig Packages for Solana Program development

Here are some other packages to help with developing Solana programs with Zig:

* [Bincode](https://github.com/joncinque/bincode-zig)
* [Borsh](https://github.com/joncinque/borsh-zig)
* [Solana Program Library](https://github.com/joncinque/solana-program-library-zig)
* [Metaplex Token-Metadata](https://github.com/joncinque/mpl-token-metadata-zig)

## Prerequisites

Requires a Solana-compatible Zig compiler, which can be built with
[solana-zig-bootstrap](https://github.com/joncinque/solana-zig-bootstrap).

It's also possible to download an appropriate compiler for your system from the
[GitHub Releases](https://github.com/joncinque/solana-zig-bootstrap/releases).

You can run the convenience script in this repo to download the compiler to
`solana-zig`:

```
./install-solana-zig.sh
./solana-zig/zig build test
```

## How to use

1. Add this package and `base58-zig` to your project:

```console
zig fetch --save https://github.com/joncinque/base58-zig/archive/refs/tags/v0.12.2.tar.gz
zig fetch --save https://github.com/joncinque/solana-sdk-zig/archive/refs/tags/v0.12.0.tar.gz
```

2. In your build.zig, add the modules that you want one by one, or use the
helpers in `build.zig`:

```zig
const std = @import("std");
const solana = @import("solana-program-sdk");

pub fn build(b: *std.build.Builder) !void {
    // Choose the on-chain target (bpf, sbf v1, sbf v2, etc)
    // Many targets exist in the package, including `bpf_target`,
    // `sbf_target`, and `sbfv2_target`.
    // See `build.zig` for more info.
    const target = b.resolveTargetQuery(solana.sbf_target);
    // Choose the optimization. `.ReleaseSmall` gives a good balance of
    // optimized CU usage and smaller size of compiled binary
    const optimize = .ReleaseSmall;
    // Define your program as a shared library
    const program = b.addSharedLibrary(.{
        .name = "program_name",
        // Give the root of your program, where the entrypoint is defined
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .target = target,
    });
    // Use the `buildProgram` helper to create the solana-sdk module, add all
    // of its required dependencies, link the program properly, and generate
    // a keypair in `zig-out/lib` along with the compiled program.
    const solana_mod = solana.buildProgram(b, program, target, optimize);

    // Optional, but if you define unit tests in your program files, you can run
    // them with `zig build test` with this step included
    const test_step = b.step("test", "Run unit tests");
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });
    lib_unit_tests.root_module.addImport("solana-program-sdk", solana_mod);
    const run_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
```

3. Setup `src/main.zig`:

```zig
const solana = @import("solana-program-sdk");

export fn entrypoint(_: [*]u8) callconv(.C) u64 {
    solana.print("Hello world!", .{});
    return 0;
}
```

4. Download the solana-zig compiler using the script in this repository:

```console
$ ./install-solana-zig.sh
```

5. Build and deploy your program on Solana devnet:

```console
$ ./solana-zig/zig build --summary all
Program ID: FHGeakPPYgDWomQT6Embr4mVW5DSoygX6TaxQXdgwDYU

$ solana airdrop -ud 1
Requesting airdrop of 1 SOL

Signature: 52rgcLosCjRySoQq5MQLpoKg4JacCdidPNXPWbJhTE1LJR2uzFgp93Q7Dq1hQrcyc6nwrNrieoN54GpyNe8H4j3T

882.4039166 SOL

$ solana program deploy -ud zig-out/lib/program_name.so
Program Id: FHGeakPPYgDWomQT6Embr4mVW5DSoygX6TaxQXdgwDYU
```

And that's it!

### Targets available

The helpers in build.zig contain various Solana targets. Here are their analogues
to the Rust build tools:

* `sbf_target` -> `cargo build-sbf`
* `bpf_target` -> `cargo build-bpf`
* `sbfv2_target` -> `cargo build-sbf --arch sbfv2`

## Unit tests

The unit tests require the solana-zig compiler as mentioned in the prerequisites.

You can run all unit tests for the library with:

```console
./solana-zig/zig build test --summary all
```

## Integration tests

There are also integration tests that build programs and run against the Agave
runtime using the
[`solana-program-test` crate](https://crates.io/crates/solana-program-test).

You can run these tests using the `test.sh` script:

```console
cd program-test/
./test.sh
```

These tests require a Rust compiler along with the solana-zig compiler, as
mentioned in the prerequisites.
