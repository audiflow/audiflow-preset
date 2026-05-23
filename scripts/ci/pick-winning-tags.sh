#!/usr/bin/env bash
# Read tag names from stdin (one per line). For each (env, major) pair,
# emit the tag with the highest minor. Output format: "env major minor tag".
# Invalid tags are dropped silently. Output order is not guaranteed.
# Portable: works on bash 3.2 (no associative arrays).
set -eu

HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PARSE="$HERE/parse-tag.sh"
[ -x "$PARSE" ] || { echo "pick-winning-tags: missing $PARSE" >&2; exit 2; }

while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  parsed="$(bash "$PARSE" "$tag" 2>/dev/null)" && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 1 ] && continue
    echo "pick-winning-tags: parse-tag failed (rc=$rc) for '$tag'" >&2
    exit "$rc"
  fi
  read -r env major minor <<<"$parsed"
  printf '%s\t%s\t%s\t%s\n' "$env" "$major" "$minor" "$tag"
done | awk -F'\t' '
{
  key = $1 "/" $2
  minor = $3 + 0
  if (!(key in best_minor) || best_minor[key] < minor) {
    best_minor[key] = minor
    best_tag[key]   = $4
    env_of[key]     = $1
    major_of[key]   = $2
  }
}
END {
  for (k in best_minor) {
    printf "%s %s %s %s\n", env_of[k], major_of[k], best_minor[k], best_tag[k]
  }
}
'
