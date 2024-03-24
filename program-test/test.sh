#!/usr/bin/env bash

ZIG="$1"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"
if [[ -z "$ZIG" ]]; then
  ZIG="$ROOT_DIR/../zig-x86_64-linux-gnu-baseline/zig"
fi

set -e
cd $ROOT_DIR/program-test
$ZIG build --summary all --verbose --global-cache-dir zig-global-cache -j1
SBF_OUT_DIR="$ROOT_DIR/program-test/zig-out/lib" cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
