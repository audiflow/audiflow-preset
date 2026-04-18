#!/usr/bin/env bash
set -euo pipefail

SCHEMA_DIR="$(cd "$(dirname "$0")/.." >/dev/null && pwd)"

mkdir -p "${SCHEMA_DIR}/docs"

echo "Generating HTML documentation from schema files..."
uv run --with json-schema-for-humans \
  generate-schema-doc \
  --config template_name=js \
  --config expand_buttons=true \
  "${SCHEMA_DIR}/playlist-definition.schema.json" "${SCHEMA_DIR}/docs/schema.html"

echo "Done. Output: schema/docs/schema.html"
