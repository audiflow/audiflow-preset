#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." >/dev/null && pwd)"

usage() {
  echo "Usage: schema/scripts/validate.sh [patterns_dir]"
  echo ""
  echo "Validates JSON config files using the audiflow-editor binary"
  echo "matched to the schema version in schema/VERSION."
  echo ""
  echo "Arguments:"
  echo "  patterns_dir  Path to patterns directory (default: patterns/)"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

PATTERNS_DIR="${1:-$REPO_ROOT/patterns}"

if [ ! -d "$PATTERNS_DIR" ]; then
  echo "error: patterns directory not found: $PATTERNS_DIR" >&2
  exit 1
fi

EDITOR_BIN="$("$SCRIPT_DIR/ensure-editor.sh")"

echo "Validating with $("$EDITOR_BIN" --version 2>&1 || echo "audiflow-editor")"
echo ""
exec "$EDITOR_BIN" validate "$PATTERNS_DIR"
