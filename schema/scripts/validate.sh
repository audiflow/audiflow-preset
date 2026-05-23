#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." >/dev/null && pwd)"

usage() {
  echo "Usage: schema/scripts/validate.sh [path ...]"
  echo ""
  echo "Validates JSON config files using the audiflow-editor binary"
  echo "matched to the schema version in schema/VERSION."
  echo ""
  echo "Arguments:"
  echo "  path  One or more files or directories to validate"
  echo "        (default: presets/). Directories are validated recursively."
  echo ""
  echo "Examples:"
  echo "  schema/scripts/validate.sh"
  echo "  schema/scripts/validate.sh presets/"
  echo "  schema/scripts/validate.sh presets/**/*.json"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -eq 0 ]; then
  set -- "$REPO_ROOT/presets"
fi

for target in "$@"; do
  if [ ! -e "$target" ]; then
    echo "error: path not found: $target" >&2
    exit 1
  fi
done

EDITOR_BIN="$("$SCRIPT_DIR/ensure-editor.sh")"

echo "Validating with $("$EDITOR_BIN" --version 2>&1 || echo "audiflow-editor")"
echo ""
exec "$EDITOR_BIN" validate "$@"
