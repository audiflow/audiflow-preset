#!/usr/bin/env bash
# Runs audiflow-editor bump-versions HEAD~1, commits "chore: bump versions"
# if anything changed, then tags ${BUMP_ENV}/v${schemaVersion}.${dataVersion}
# and pushes both commit and tag to ${GIT_REMOTE} (default: origin).
#
# Idempotent: if there is no diff after bump, no commit, no tag, no push.
# Requires: git, jq, audiflow-editor in PATH.
# Required env: BUMP_ENV (prod|dev)
set -eu

HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

: "${BUMP_ENV:?BUMP_ENV (prod|dev) required}"
GIT_REMOTE="${GIT_REMOTE:-origin}"

case "$BUMP_ENV" in prod|dev) ;; *) echo "BUMP_ENV must be prod or dev" >&2; exit 1 ;; esac

require_cmd git
require_cmd jq
require_cmd audiflow-editor

# Skip bump on the very first commit (no HEAD~1).
if git rev-parse --verify -q HEAD~1 >/dev/null; then
  audiflow-editor bump-versions HEAD~1
else
  echo "bump-and-tag: HEAD~1 missing, skipping bump-versions"
fi

# Bot identity (workflow-level config may not stick in scripts).
git config user.name  "audiflow-ci-bot[bot]"
git config user.email "audiflow-ci-bot[bot]@users.noreply.github.com"

git add presets/
if git diff --cached --quiet; then
  echo "bump-and-tag: no version changes"
else
  git commit -m "chore: bump versions"
  git push "$GIT_REMOTE" HEAD
fi

major="$(read_schema_version presets/meta.json)"
data="$(read_data_version presets/meta.json)"
tag="${BUMP_ENV}/v${major}.${data}"

# Refuse to overwrite an existing tag (defense in depth; tag protection should also).
if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  echo "bump-and-tag: tag ${tag} already exists; skipping"
  exit 0
fi

git tag "$tag"
git push "$GIT_REMOTE" "refs/tags/${tag}"
echo "bump-and-tag: tagged ${tag}"
