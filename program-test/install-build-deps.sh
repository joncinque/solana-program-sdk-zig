#!/usr/bin/env bash
set -e
case $(uname -s | cut -c1-7) in
"Windows" | "MINGW64")
  export PERL="$(which perl)"
  export OPENSSL_SRC_PERL="$(which perl)"
  choco install openssl --version 3.4.1 --install-arguments="'/DIR=C:\OpenSSL'" -y
  export OPENSSL_LIB_DIR='C:\OpenSSL\lib\VC\x64\MT'
  export OPENSSL_INCLUDE_DIR='C:\OpenSSL\include'
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
