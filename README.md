# solana-zig

## Setup

1. Add this repository as a submodule to your project:

```console
git submodule init
git submodule add https://github.com/joncinque/solana-zig.git sol
git submodule update --init --recursive
```

2. In your build.zig, add the modules that you want, or use the helpers in `build.zig`:

```zig
const std = @import("std");
const sol = @import("sol/build.zig");

// Assume:
// * `build` is the *std.build.Builder`
// * `program` is a `*std.build.Step.Compile` created with `build.addSharedLibrary(...)` and all of your program files
// * 'sol/' is the directory with this repository within your project

const sol_modules = sol.allSolModules(build, "sol/");

inline for (sol_modules) |package| {
    program.addModule(package.name, package.module);
}
```

## Example Program

1. Setup build.zig:

```zig
const std = @import("std");
const sol = @import("sol/build.zig");

const sol_pkgs = sol.Packages("sol/");

pub fn build(b: *std.build.Builder) !void {
    const program = b.addSharedLibrary(.{
        .name = "helloworld",
        .root_source_file = .{ .path = "src/main.zig"},
        .optimize = .ReleaseSmall,
        .target = sol.sbf_target,
    });
    try sol.buildProgram(b, program, "sol/");
}
```

2. Setup main.zig:

```zig
const sol = @import("sol");

export fn entrypoint(_: [*]u8) callconv(.C) u64 {
    sol.print("Hello world!", .{});
    return 0;
}
```

3. Build and deploy your program on Solana devnet:

```console
$ zig build
Program ID: FHGeakPPYgDWomQT6Embr4mVW5DSoygX6TaxQXdgwDYU

$ solana airdrop -ud 1
Requesting airdrop of 1 SOL

Signature: 52rgcLosCjRySoQq5MQLpoKg4JacCdidPNXPWbJhTE1LJR2uzFgp93Q7Dq1hQrcyc6nwrNrieoN54GpyNe8H4j3T

882.4039166 SOL

$ solana program deploy -ud zig-out/lib/libhelloworld.so
Program Id: FHGeakPPYgDWomQT6Embr4mVW5DSoygX6TaxQXdgwDYU
```

## Targets available

The helpers in build.zig contain various Solana targets. Here are their analogues
to the Rust build tools:

* `sbf_target` -> `cargo build-sbf`
* `bpf_target` -> `cargo build-bpf`
* `sbfv2_target` -> `cargo build-sbf --arch sbfv2`
