#!/usr/bin/env bash
set -e
case $(uname -s | cut -c1-7) in
"Windows" | "MINGW64")
  ;;
"Darwin")
  ;;
"Linux")
  ;;
*)
  echo "Unknown Operating System"
  exit 1
  ;;
esac
