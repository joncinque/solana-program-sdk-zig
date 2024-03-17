#!/usr/bin/env bash

set -e
../../zig-native-linux-gnu-native/zig build --summary all
SBF_OUT_DIR=./zig-out/lib cargo test

