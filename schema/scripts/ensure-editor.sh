#!/usr/bin/env bash
# Downloads the audiflow-editor binary matching schema/VERSION if not cached.
# Prints the path to the binary on stdout.
set -euo pipefail

SCHEMA_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd)"
REPO_ROOT="$(cd "$SCHEMA_DIR/.." >/dev/null && pwd)"
VERSION_FILE="$SCHEMA_DIR/VERSION"
CACHE_DIR="$REPO_ROOT/.cache/bin"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI is required but not installed. See https://cli.github.com/" >&2
  exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
  echo "error: schema/VERSION not found" >&2
  exit 1
fi

SCHEMA_VERSION="v$(cat "$VERSION_FILE" | tr -d '[:space:]')"

detect_binary_name() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)
      case "$arch" in
        x86_64)          echo "audiflow-editor-x86_64-unknown-linux-gnu" ;;
        aarch64 | arm64) echo "audiflow-editor-aarch64-unknown-linux-gnu" ;;
        *)               echo "error: unsupported architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    Darwin)
      case "$arch" in
        x86_64)  echo "audiflow-editor-x86_64-apple-darwin" ;;
        arm64)   echo "audiflow-editor-aarch64-apple-darwin" ;;
        *)       echo "error: unsupported architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    *)
      echo "error: unsupported OS: $os" >&2
      exit 1
      ;;
  esac
}

BINARY_NAME="$(detect_binary_name)"
EDITOR_BIN="$CACHE_DIR/$SCHEMA_VERSION/$BINARY_NAME"

if [ ! -x "$EDITOR_BIN" ]; then
  echo "Downloading audiflow-editor $SCHEMA_VERSION..." >&2
  mkdir -p "$CACHE_DIR/$SCHEMA_VERSION"
  gh release download "$SCHEMA_VERSION" \
    --repo audiflow/audiflow-smartplaylist-editor \
    --pattern "$BINARY_NAME" \
    --output "$EDITOR_BIN" >&2
  chmod +x "$EDITOR_BIN"
  echo "" >&2
fi

echo "$EDITOR_BIN"
