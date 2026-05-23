#!/usr/bin/env bash
# Rebuild a gh-pages worktree from the current repo's tags.
#
# Args:
#   $1  path to source repo checkout (must have tags fetched)
#   $2  path to gh-pages checkout (must exist on the gh-pages branch)
#
# Behavior:
#   - Runs select-deploy-targets.sh in $1.
#   - For each winning tag, materializes a worktree and rsyncs presets/ into
#     ${gh_pages}/${deployDir}/v${major}/.
#   - Then rsyncs --delete from a staging dir into gh-pages to drop directories
#     no longer backed by any tag (e.g. legacy assets-stg/*).
set -eu

HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${1:?source repo path required}"
GHP="${2:?gh-pages checkout path required}"
[ -d "$SRC/.git" ] || { echo "$SRC is not a git repo" >&2; exit 1; }
[ -d "$GHP/.git" ] || { echo "$GHP is not a git checkout" >&2; exit 1; }

# Resolve to absolute paths so worktree-add and rsync don't get confused by cd.
SRC="$(CDPATH= cd -P -- "$SRC" && pwd)"
GHP="$(CDPATH= cd -P -- "$GHP" && pwd)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"; (cd "$SRC" && git worktree prune) >/dev/null 2>&1 || true' EXIT

cd "$SRC"

set -o pipefail

plan="$(bash "$HERE/select-deploy-targets.sh")"

if [ -z "$plan" ]; then
  if [ "${REBUILD_ALLOW_EMPTY:-0}" != "1" ]; then
    echo "rebuild-gh-pages: empty deploy plan; refusing to wipe gh-pages. Set REBUILD_ALLOW_EMPTY=1 to override." >&2
    exit 3
  fi
  echo "rebuild-gh-pages: empty plan accepted via REBUILD_ALLOW_EMPTY=1" >&2
fi

while IFS=' ' read -r env major minor tag dir; do
  [ -z "${env:-}" ] && continue
  if [ -z "${dir:-}" ]; then
    echo "rebuild-gh-pages: missing deployDir for tag '$tag'" >&2
    exit 1
  fi
  wt="$(mktemp -d)"
  git worktree add --quiet --detach "$wt" "$tag"
  target="$STAGING/$dir/v$major"
  mkdir -p "$target"
  rsync -a --delete "$wt/presets/" "$target/"
  git worktree remove --force "$wt" || true
  rm -rf "$wt"
done <<<"$plan"

# Sync staging into gh-pages root. --delete drops any tree without a backing tag,
# but excludes top-level files we don't manage (CNAME, README, .gitignore, .git).
rsync -a --delete \
  --exclude '/.git/' \
  --exclude '/.gitignore' \
  --exclude '/CNAME' \
  --exclude '/README.md' \
  "$STAGING/" "$GHP/"
