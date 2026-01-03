#!/usr/bin/env bash

ZIG="$1"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"
if [[ -z "$ZIG" ]]; then
  ZIG="$ROOT_DIR/solana-zig/zig"
fi

set -e
cd $ROOT_DIR/program-test
$ZIG build --summary all --verbose
cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
