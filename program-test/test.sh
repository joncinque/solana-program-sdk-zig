#!/usr/bin/env bash

ZIG="$1"
ROOT_DIR="$(cd "$(dirname "$0")"/..; pwd)"
if [[ -z "$ZIG" ]]; then
  ZIG="$ROOT_DIR/zig-solana/zig"
fi

set -e
cd $ROOT_DIR/program-test
for i in $(seq 1 5)
do
  $ZIG build --summary all --verbose && break || sleep 1
done
SBF_OUT_DIR="$ROOT_DIR/program-test/zig-out/lib" cargo test --manifest-path "$ROOT_DIR/program-test/Cargo.toml"
