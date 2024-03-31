#!/usr/bin/env bash

if [[ -n $ZIG_SOLANA_VERSION ]]; then
  zig_solana_version="$ZIG_SOLANA_VERSION"
else
  zig_solana_version="v1.39"
fi
zig_solana_release_url="https://github.com/joncinque/zig-bootstrap-solana/releases/download/solana-$zig_solana_version"

output_dir="$1"
if [[ -z $output_dir ]]; then
  output_dir="zig-solana"
fi
output_dir="$(mkdir -p "$output_dir"; cd "$output_dir"; pwd)"
cd $output_dir

arch=$(uname -m)
case $(uname -s | cut -c1-7) in
"Linux")
  os="linux"
  abi="gnu"
  ;;
"Darwin")
  os="macos"
  abi="none"
  ;;
"Windows" | "MINGW64")
  os="windows"
  abi="gnu"
  ;;
*)
  echo "install-zig-solana.sh: Unknown OS $(uname -s)" >&2
  exit 1
  ;;
esac

zig_solana_tar=zig-$arch-$os-$abi.tar.bz2
url="$zig_solana_release_url/$zig_solana_tar"
echo "Downloading $url"
curl --proto '=https' --tlsv1.2 -SfOL "$url"
echo "Unpacking $zig_solana_tar"
tar -xjf $zig_solana_tar
rm $zig_solana_tar

zig_solana_dir="zig-$arch-$os-$abi-baseline"
mv "$zig_solana_dir"/* .
rmdir $zig_solana_dir
echo "zig-solana compiler available at $output_dir"
