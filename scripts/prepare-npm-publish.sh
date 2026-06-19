#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RN_PKG="$REPO_ROOT/packages/react-native-enriched-markdown"
CORE_CPP="$REPO_ROOT/packages/core/cpp"

mode="${1:-}"

case "$mode" in
  prepack)
    if [[ ! -d "$CORE_CPP" ]]; then
      echo "error: core cpp directory not found at $CORE_CPP" >&2
      exit 1
    fi

    cd "$RN_PKG"
    rm -rf cpp
    mkdir -p cpp
    cp -R "$CORE_CPP/." cpp/
    ;;
  postpack)
    cd "$RN_PKG"
    rm -rf cpp
    ln -s ../core/cpp cpp
    ;;
  *)
    echo "usage: $0 prepack|postpack" >&2
    exit 1
    ;;
esac
