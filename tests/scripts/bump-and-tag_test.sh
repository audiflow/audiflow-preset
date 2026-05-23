#!/usr/bin/env bash
# Smoke test of bump-and-tag.sh against a fake editor binary in a temp git repo.
set -u
HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH= cd -P -- "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/bump-and-tag.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build fake editor binary that bumps dataVersion in presets/meta.json.
mkdir -p "$TMP/bin"
cat >"$TMP/bin/audiflow-editor" <<'EOF'
#!/usr/bin/env bash
# Fake audiflow-editor: supports "bump-versions <range>" by incrementing
# .dataVersion in presets/meta.json.
set -eu
[ "${1:-}" = "bump-versions" ] || { echo "fake: unsupported $*" >&2; exit 1; }
meta="presets/meta.json"
cur="$(jq -r .dataVersion "$meta")"
new=$((cur + 1))
tmp="$(mktemp)"
jq --argjson v "$new" '.dataVersion = $v' "$meta" >"$tmp"
mv "$tmp" "$meta"
EOF
chmod +x "$TMP/bin/audiflow-editor"
export PATH="$TMP/bin:$PATH"

# Bare remote + working repo.
git init -q -b main "$TMP/remote.git" --bare
git init -q -b main "$TMP/work"
cd "$TMP/work"
git config user.email t@t.t
git config user.name tester
git remote add origin "$TMP/remote.git"

mkdir presets
cat >presets/meta.json <<'EOF'
{"schemaVersion": 7, "dataVersion": 41, "presets": []}
EOF
git add presets/meta.json
git commit -q -m "init"
git push -q origin main

# Add a real change so bump-versions has something to bump.
echo '{"schemaVersion": 7, "dataVersion": 41, "presets": [{"id":"x"}]}' >presets/meta.json
git add presets/meta.json
git commit -q -m "feat: x"
git push -q origin main

# Run bump-and-tag for env=prod.
output="$(BUMP_ENV=prod GIT_REMOTE=origin bash "$S" 2>&1)" || {
  echo "$output"
  assert_eq "bump-and-tag rc" "0" "1"
  summary
}

# Expect bot commit + tag prod/v7.42 created and pushed.
last_msg="$(git log -1 --pretty=%s)"
assert_eq "bot commit subject" "chore: bump versions" "$last_msg"

tag_count="$(git tag -l 'prod/v7.42' | wc -l | tr -d ' ')"
assert_eq "tag created locally" "1" "$tag_count"

remote_tag="$(git --git-dir="$TMP/remote.git" tag -l 'prod/v7.42' | wc -l | tr -d ' ')"
assert_eq "tag pushed to remote" "1" "$remote_tag"

# Re-run with no presets change: should not commit, should not tag again.
output2="$(BUMP_ENV=prod GIT_REMOTE=origin bash "$S" 2>&1)"
last_msg2="$(git log -1 --pretty=%s)"
assert_eq "no-op leaves last commit unchanged" "chore: bump versions" "$last_msg2"

summary
