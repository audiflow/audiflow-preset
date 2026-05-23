#!/usr/bin/env bash
# Build the Pages deploy tree from the current repo's tags.
#
# Args:
#   $1  path to source repo checkout (must have prod/v*.* and dev/v*.* tags fetched)
#   $2  path to output directory (will be created; existing contents overwritten)
#
# Behavior:
#   - Runs select-deploy-targets.sh in $1.
#   - For each winning tag, materializes a git worktree and rsyncs presets/ into
#     ${out}/${deployDir}/v${major}/.
#   - Output tree is suitable for actions/upload-pages-artifact (no .git, no
#     deploy-history maintenance).
#
# Safety:
#   - Aborts with rc 3 when the deploy plan is empty unless BUILD_ALLOW_EMPTY=1
#     is set. Empty plans almost always indicate a misconfiguration; the override
#     exists for the post-sunset case where every major's tags have been deleted.
set -eu

HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:?source repo path required}"
OUT="${2:?output directory required}"
[ -d "$SRC/.git" ] || { echo "$SRC is not a git repo" >&2; exit 1; }

SRC="$(CDPATH= cd -P -- "$SRC" && pwd)"

mkdir -p "$OUT"
OUT="$(CDPATH= cd -P -- "$OUT" && pwd)"

trap '(cd "$SRC" && git worktree prune) >/dev/null 2>&1 || true' EXIT

cd "$SRC"

set -o pipefail

plan="$(bash "$HERE/select-deploy-targets.sh")"

if [ -z "$plan" ]; then
  if [ "${BUILD_ALLOW_EMPTY:-0}" != "1" ]; then
    echo "build-pages-tree: empty deploy plan; refusing to publish empty site. Set BUILD_ALLOW_EMPTY=1 to override." >&2
    exit 3
  fi
  echo "build-pages-tree: empty plan accepted via BUILD_ALLOW_EMPTY=1" >&2
fi

while IFS=' ' read -r env major minor tag dir; do
  [ -z "${env:-}" ] && continue
  if [ -z "${dir:-}" ]; then
    echo "build-pages-tree: missing deployDir for tag '$tag'" >&2
    exit 1
  fi
  wt="$(mktemp -d)"
  git worktree add --quiet --detach "$wt" "$tag"
  target="$OUT/$dir/v$major"
  mkdir -p "$target"
  rsync -a --delete "$wt/presets/" "$target/"
  git worktree remove --force "$wt" || true
  rm -rf "$wt"
done <<<"$plan"
