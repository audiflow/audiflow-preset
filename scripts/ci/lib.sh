#!/usr/bin/env bash
# Shared helpers. Source this file; do not execute.
set -eu

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

# Read .schemaVersion from a presets/meta.json file. Prints integer, errors if missing.
read_schema_version() {
  local meta="${1:-presets/meta.json}"
  local v
  v="$(jq -er '.schemaVersion' "$meta")" || {
    echo "read_schema_version: .schemaVersion missing in $meta" >&2
    return 1
  }
  printf '%s\n' "$v"
}

# Read .dataVersion from a presets/meta.json file. Prints integer, errors if missing.
read_data_version() {
  local meta="${1:-presets/meta.json}"
  local v
  v="$(jq -er '.dataVersion' "$meta")" || {
    echo "read_data_version: .dataVersion missing in $meta" >&2
    return 1
  }
  printf '%s\n' "$v"
}

# Map env name to gh-pages deploy directory.
deploy_dir_for_env() {
  case "${1:-}" in
    prod) printf 'assets\n' ;;
    dev)  printf 'assets-dev\n' ;;
    *)
      echo "deploy_dir_for_env: unknown env '$1'" >&2
      return 1
      ;;
  esac
}
