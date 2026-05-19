#!/usr/bin/env bash
# Compile md4c + the WASM wrapper to a single self-contained JS file.
#
# Prerequisites:
#   brew install emscripten    # macOS
#   # or follow https://emscripten.org/docs/getting_started/downloads.html
#
# Usage:
#   bash cpp/wasm/build.sh
#
# Output:
#   src/web/wasm/md4c.js   — Emscripten glue with WASM binary inlined as base64
#                            (SINGLE_FILE=1 means no separate .wasm file is needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$REPO_ROOT/src/web/wasm"

mkdir -p "$OUT_DIR"

echo "Building md4c WASM…"

# Compile the C file separately (no -std=c++17)
emcc \
  -I "$REPO_ROOT/cpp" \
  -O2 \
  -c "$REPO_ROOT/cpp/md4c/md4c.c" \
  -o "$OUT_DIR/md4c.o"

# Compile C++ sources and link everything together
emcc \
  "$SCRIPT_DIR/md4c_wasm.cpp" \
  "$SCRIPT_DIR/ASTSerializer.cpp" \
  "$REPO_ROOT/cpp/parser/MD4CParser.cpp" \
  "$OUT_DIR/md4c.o" \
  -I "$REPO_ROOT/cpp" \
  -I "$SCRIPT_DIR" \
  -O2 \
  -std=c++17 \
  -Wswitch \
  -s WASM=1 \
  -s SINGLE_FILE=1 \
  -s EXPORTED_FUNCTIONS='["_parseMarkdown"]' \
  -s EXPORTED_RUNTIME_METHODS='["ccall","cwrap","UTF8ToString"]' \
  -s ENVIRONMENT='web' \
  -s MODULARIZE=1 \
  -s EXPORT_NAME='createMd4cModule' \
  -s STACK_SIZE=8MB \
  -s INITIAL_MEMORY=16MB \
  -s MAXIMUM_MEMORY=512MB \
  -s ALLOW_MEMORY_GROWTH=1 \
  -o "$OUT_DIR/md4c.js"

rm "$OUT_DIR/md4c.o"

echo "Done → $OUT_DIR/md4c.js"
