#!/usr/bin/env bash
set -e
case $(uname -s | cut -c1-7) in
"Windows" | "MINGW64")
  cat > vcpkg.json <<EOL
{
  "dependencies": ["openssl"],
  "overrides": [
    {
      "name": "openssl",
      "version": "3.4.1"
    }
  ],
  "builtin-baseline": "5ee5eee0d3e9c6098b24d263e9099edcdcef6631"
}
EOL
  vcpkg install --triplet x64-windows-static-md
  rm vcpkg.json
  export "OPENSSL_LIB_DIR=$GITHUB_WORKSPACE/vcpkg_installed/x64-windows-static-md/lib"
  export "OPENSSL_INCLUDE_DIR=$GITHUB_WORKSPACE/vcpkg_installed/x64-windows-static-md/include"
  choco install protoc
  export PROTOC='C:\ProgramData\chocolatey\lib\protoc\tools\bin\protoc.exe'
  ;;
"Darwin")
  brew install protobuf
  ;;
"Linux")
  sudo apt update
  sudo apt install protobuf-compiler -y
  ;;
*)
  echo "Unknown Operating System"
  exit 1
  ;;
esac
