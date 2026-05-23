#!/usr/bin/env bash
# Emits the deploy plan as space-separated lines:
#   env major minor tag deployDir
# One line per (env, major) winning tag (highest minor).
# Tags whose presets/meta.json:.schemaVersion disagrees with the tag's major
# are skipped with a ::warning:: line on stderr.
#
# Must be run inside a git repo where all relevant tags are present locally.
set -eu

HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
PICK="$HERE/pick-winning-tags.sh"

require_cmd git
require_cmd jq
[ -x "$PICK" ] || { echo "select-deploy-targets: missing $PICK" >&2; exit 2; }

tag_list="$(git tag -l 'prod/v*.*' 'dev/v*.*')"

printf '%s\n' "$tag_list" | bash "$PICK" | while read -r env major minor tag; do
  [ -z "${env:-}" ] && continue
  if ! meta_json="$(git show "${tag}:presets/meta.json" 2>/dev/null)"; then
    printf '::warning::tag %s has no presets/meta.json; skipped\n' "$tag" >&2
    continue
  fi
  tag_schema="$(printf '%s' "$meta_json" | jq -r '.schemaVersion // empty')"
  if [ "$tag_schema" != "$major" ]; then
    printf '::warning::tag %s claims major %s but meta.json schemaVersion=%s; skipped\n' \
      "$tag" "$major" "$tag_schema" >&2
    continue
  fi
  dir="$(deploy_dir_for_env "$env")"
  printf '%s %s %s %s %s\n' "$env" "$major" "$minor" "$tag" "$dir"
done
