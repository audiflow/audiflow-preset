#!/usr/bin/env bash
# Parse a tag of the form {env}/v{Major}.{minor}.
# env must be 'prod' or 'dev'. Major and minor must be all digits.
# Prints "env major minor" on stdout. Exits 1 on bad input.
set -eu

tag="${1:-}"
if [ -z "$tag" ]; then
  echo "parse-tag: missing tag" >&2
  exit 1
fi

# Strict regex: ^(prod|dev)/v([0-9]+)\.([0-9]+)$
if [[ ! "$tag" =~ ^(prod|dev)/v([0-9]+)\.([0-9]+)$ ]]; then
  echo "parse-tag: invalid tag '$tag'" >&2
  exit 1
fi

printf '%s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
