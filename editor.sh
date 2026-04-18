#!/usr/bin/env bash
# Launch the audiflow-editor web UI for this data repo.
# Downloads the correct binary version automatically.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" >/dev/null && pwd)"

EDITOR_BIN="$("$REPO_ROOT/schema/scripts/ensure-editor.sh")"

echo "Starting audiflow-editor..."
echo "Open http://localhost:8080 in your browser."
echo ""
exec "$EDITOR_BIN" serve --data-dir "$REPO_ROOT" "$@"
