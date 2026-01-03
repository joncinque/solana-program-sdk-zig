# solana-program-sdk-zig

Write Solana on-chain programs in Zig using the **standard Zig compiler**!

This SDK uses a two-stage build pipeline:
1. Zig → LLVM bitcode (using standard `bpfel-freestanding` target)
2. LLVM bitcode → Solana eBPF (using `sbpf-linker`)

No custom Zig compiler fork required!

## Features

- Uses standard Zig compiler (0.15.2+)
- Zero-copy input deserialization
- Type-safe API matching Rust SDK
- MurmurHash3-based syscall bindings
- Full PDA and CPI support
- Build helper functions for easy integration

## Other Zig Packages for Solana Program development

* [Base-58](https://github.com/joncinque/base58-zig)
* [Bincode](https://github.com/joncinque/bincode-zig)
* [Borsh](https://github.com/joncinque/borsh-zig)
* [Solana Program Library](https://github.com/joncinque/solana-program-library-zig)
* [Metaplex Token-Metadata](https://github.com/joncinque/mpl-token-metadata-zig)

## Prerequisites

1. **Zig 0.15.2+** - Standard Zig compiler
   ```console
   # Download from https://ziglang.org/download/
   ```

2. **LLVM 18** - Required by sbpf-linker
   ```console
   # Ubuntu/Debian
   sudo apt-get install llvm-18 llvm-18-dev
   
   # macOS
   brew install llvm@18
   ```

3. **sbpf-linker** - Solana BPF linker (LLVM-based)
   ```console
   cargo install --git https://github.com/blueshift-gg/sbpf-linker.git
   ```

4. **Solana CLI** - For deployment
   ```console
   sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
   ```

## Quick Start

### 1. Create a new project

```console
mkdir my-solana-program && cd my-solana-program
zig init
```

### 2. Add dependencies to `build.zig.zon`

```zig
.dependencies = .{
    .solana_program_sdk = .{
        .url = "https://github.com/joncinque/solana-program-sdk-zig/archive/refs/tags/v0.17.0.tar.gz",
        .hash = "...", // Run zig build to get the hash
    },
    .base58 = .{
        .url = "https://github.com/joncinque/base58-zig/archive/refs/tags/v0.15.0.tar.gz",
        .hash = "...",
    },
},
```

Or use `zig fetch`:
```console
zig fetch --save https://github.com/joncinque/solana-program-sdk-zig/archive/refs/tags/v0.17.0.tar.gz
zig fetch --save https://github.com/joncinque/base58-zig/archive/refs/tags/v0.15.0.tar.gz
```

### 3. Write your program

Create `src/main.zig`:

```zig
const sdk = @import("solana_program_sdk");

fn processInstruction(
    program_id: *sdk.PublicKey,
    accounts: []sdk.Account,
    data: []const u8,
) sdk.ProgramResult {
    _ = accounts;
    _ = data;
    
    // Log a message
    sdk.print("Hello from Zig!", .{});
    
    // Log the program ID
    sdk.log.logPubkey(&program_id.bytes);
    
    return .ok;
}

comptime {
    sdk.entrypoint(&processInstruction);
}
```

### 4. Configure build.zig

Using the SDK's helper functions:

```zig
const std = @import("std");
const solana = @import("solana_program_sdk");

pub fn build(b: *std.Build) !void {
    // Create test step
    const test_step = b.step("test", "Run unit tests");
    
    // Build the Solana program with tests
    const program = solana.addSolanaProgramWithTests(b, .{
        .name = "my_program",
        .root_source_file = b.path("src/main.zig"),
        .optimize = .ReleaseSmall,
    }, test_step);

    // Default install builds the .so file
    b.getInstallStep().dependOn(program.getInstallStep());
    
    // Optional: add a bitcode-only step (no sbpf-linker required)
    const bc_step = b.step("bitcode", "Generate LLVM bitcode only");
    bc_step.dependOn(&program.bitcode_step.step);
}
```

### 5. Build and deploy

```console
# Build (generates .bc and .so)
zig build

# Or just generate bitcode (no sbpf-linker required)
zig build bitcode

# Run tests
zig build test

# Deploy to devnet
solana airdrop -ud 1
solana program deploy -ud zig-out/lib/my_program.so
```

## How It Works

### Two-Stage Build Pipeline

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Zig Source    │───>│ LLVM Bitcode │───>│  Solana eBPF    │
│   (.zig files)  │    │   (.bc file) │    │   (.so file)    │
└─────────────────┘    └──────────────┘    └─────────────────┘
        │                     │                     │
   Standard Zig          sbpf-linker           Deploy to
   Compiler              (LTO pass)            Solana
```

### Syscalls via Function Pointers

Solana syscalls are invoked via MurmurHash3-32 hashed function pointers:

```zig
// Hash: murmur3_32("sol_log_", 0) = 0x207559bd
pub const sol_log_ = @as(*align(1) const fn([*]const u8, u64) callconv(.c) void, @ptrFromInt(0x207559bd));
```

The Solana VM resolves these magic addresses at runtime.

## API Reference

### Entrypoint

```zig
const sdk = @import("solana_program_sdk");

fn processInstruction(
    program_id: *sdk.PublicKey,
    accounts: []sdk.Account,
    data: []const u8,
) sdk.ProgramResult {
    // Your program logic here
    return .ok;  // or .{ .err = sdk.ProgramError.InvalidArgument }
}

comptime {
    sdk.entrypoint(&processInstruction);
}
```

### Logging

```zig
// Log a static message (works in BPF mode)
sdk.print("Hello Solana!", .{});

// Log a public key (use syscall directly)
sdk.log.logPubkey(&pubkey.bytes);

// Log 5 u64 values
sdk.log.log64(1, 2, 3, 4, 5);

// Log compute units consumed
sdk.log.logComputeUnits();
```

> **Note**: In BPF mode, `sdk.print` only supports static strings. 
> For dynamic values, use `log64` for numbers or `logPubkey` for public keys.

### Program Derived Addresses

```zig
const pda = try sdk.PublicKey.findProgramAddress(.{"seed"}, program_id);
// pda.address - the derived address
// pda.bump_seed - the bump seed
```

### Error Handling

```zig
fn processInstruction(...) sdk.ProgramResult {
    if (invalid_condition) {
        return .{ .err = sdk.ProgramError.InvalidArgument };
    }
    return .ok;
}
```

## Build Helpers

The SDK provides two helper functions for building Solana programs:

### `addSolanaProgram`

Build a Solana program without tests:

```zig
const program = solana.addSolanaProgram(b, .{
    .name = "my_program",
    .root_source_file = b.path("src/main.zig"),
    .optimize = .ReleaseSmall,  // optional, defaults to ReleaseSmall
});
b.getInstallStep().dependOn(program.getInstallStep());
```

### `addSolanaProgramWithTests`

Build a Solana program with unit tests:

```zig
const test_step = b.step("test", "Run unit tests");
const program = solana.addSolanaProgramWithTests(b, .{
    .name = "my_program",
    .root_source_file = b.path("src/main.zig"),
}, test_step);
```

### SolanaProgram struct

Both functions return a `SolanaProgram` struct:

```zig
pub const SolanaProgram = struct {
    bitcode_step: *std.Build.Step.Run,  // Generates .bc file
    link_step: *std.Build.Step.Run,     // Links to .so file
    install_step: *std.Build.Step,      // Final install step
    
    pub fn getInstallStep(self: SolanaProgram) *std.Build.Step;
};
```

## Unit Tests

Run SDK unit tests:

```console
zig build test --summary all
```

## Integration Tests

Integration tests use `solana-program-test` crate:

```console
cd program-test/
./test.sh
```

## Project Structure

```
solana-program-sdk-zig/
├── src/
│   ├── root.zig          # Main module exports
│   ├── syscalls.zig      # Solana syscalls (MurmurHash3 pointers)
│   ├── entrypoint.zig    # Program entrypoint
│   ├── error.zig         # ProgramError matching Rust SDK
│   ├── public_key.zig    # PublicKey + PDA functions
│   ├── account.zig       # Account type
│   ├── context.zig       # Input deserialization
│   └── log.zig           # Logging utilities
├── tools/
│   └── murmur3.zig       # MurmurHash3 implementation
├── program-test/         # Integration tests
└── build.zig             # Build configuration with helpers
```

## Troubleshooting

### sbpf-linker can't find LLVM

If you see errors about LLVM shared libraries, set `LD_LIBRARY_PATH`:

```console
export LD_LIBRARY_PATH=/usr/lib/llvm-18/lib:$LD_LIBRARY_PATH
```

The SDK's build helpers automatically set this for you.

### Format arguments don't work in BPF mode

In BPF mode, `sdk.print` doesn't support format arguments like `{s}` or `{d}`.
Use the syscall-based logging functions instead:

```zig
// Instead of: sdk.print("Value: {}", .{value});
// Use:
sdk.log.log64(value, 0, 0, 0, 0);

// Instead of: sdk.print("Key: {f}", .{pubkey});
// Use:
sdk.log.logPubkey(&pubkey.bytes);
```

## License

MIT
