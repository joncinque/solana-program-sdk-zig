# solana-zig

Write Solana on-chain programs in Zig!

If you want a more complete program example, please see the
[`solana-zig-helloworld` repo](https://github.com/joncinque/solana-zig-helloworld),
which also provides tests and a CLI.

## Prerequisites

Requires a Solana-compatible Zig compiler, which can be built with
[zig-bootstrap-solana](https://github.com/joncinque/zig-bootstrap-solana).

It's also possible to download an appropriate compiler for your system from the
[GitHub Releases](https://github.com/joncinque/zig-bootstrap-solana/releases).

## How to use

1. Add this repository as a submodule to your project:

```console
git submodule init
git submodule add https://github.com/joncinque/solana-zig.git sol
git submodule update --init --recursive
```

2. In your build.zig, add the modules that you want one by one, or use the
helpers in `build.zig`:

```zig
const std = @import("std");
const sol = @import("sol/sol.zig");

pub fn build(b: *std.build.Builder) !void {
    // Define your program as a shared library
    const program = b.addSharedLibrary(.{
        .name = "program_name",
        // Give the root of your program, where the entrypoint is defined
        .root_source_file = .{ .path = "src/main.zig" },
        // `.ReleaseSmall` gives a good balance of optimized CU usage and smaller
        // size of compiled binary
        .optimize = .ReleaseSmall,
        // Many targets exist in the `sol` package, including `bpf_target`,
        // `sbf_target`, and `sbfv2_target`.
        // See `build.zig` for more info.
        .target = sol.sbf_target,
    });
    // Give the path to your local submodule of this repo to link the appropriate
    // modules
    try sol.buildProgram(b, program, "sol/");

    // Optional, but if you define unit tests in your program files, you can run
    // them with `zig build test` with this step included
    const test_step = b.step("test", "Run unit tests");
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });
    sol.addSolModules(b, unit_tests, "sol/");
    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
```

3. Setup `src/main.zig`:

```zig
const sol = @import("sol");

export fn entrypoint(_: [*]u8) callconv(.C) u64 {
    sol.print("Hello world!", .{});
    return 0;
}
```

4. Build and deploy your program on Solana devnet:

```console
$ path/to/solana-zig/compiler/zig build --summary all
Program ID: FHGeakPPYgDWomQT6Embr4mVW5DSoygX6TaxQXdgwDYU

$ solana airdrop -ud 1
Requesting airdrop of 1 SOL

Signature: 52rgcLosCjRySoQq5MQLpoKg4JacCdidPNXPWbJhTE1LJR2uzFgp93Q7Dq1hQrcyc6nwrNrieoN54GpyNe8H4j3T

882.4039166 SOL

$ solana program deploy -ud zig-out/lib/libprogram_name.so
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
/path/to/your/solana-zig/compiler/zig build test
```

## Integration tests

There are also integration tests that build programs and run against the Agave
runtime using the
[`solana-program-test` crate](https://crates.io/solana-program-test).

You can run these tests using the `test.sh` script:

```console
cd program-test/
./test.sh
```

These tests require a Rust compiler along with the solana-zig compiler, as
mentioned in the prerequisites.
