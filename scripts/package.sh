#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
rm -f build/com.fingers986.volumebartheme_*.ipk
./node_modules/.bin/ares-package app --no-minify -o build
