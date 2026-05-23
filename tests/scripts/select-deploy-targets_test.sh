#!/usr/bin/env bash
# Tests select-deploy-targets.sh against a fixture git repo with seeded tags.
set -u
HERE="$(CDPATH= cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH= cd -P -- "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/select-deploy-targets.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git init -q -b main "$TMP/repo"
cd "$TMP/repo"
git config user.email t@t.t
git config user.name tester

mkdir presets
make_commit() {
  local schema="$1" data="$2" msg="$3"
  cat >presets/meta.json <<EOF
{"schemaVersion": $schema, "dataVersion": $data}
EOF
  git add presets/meta.json
  git commit -q -m "$msg"
}

# Build history with several major/minor combos and seed tags on the matching
# commits. Tag each ENV (prod/dev) variant where useful.
make_commit 7 1  "v7.1";  git tag prod/v7.1;  git tag dev/v7.1
make_commit 7 2  "v7.2";  git tag dev/v7.2
make_commit 7 10 "v7.10"; git tag prod/v7.10
make_commit 8 0  "v8.0";  git tag prod/v8.0;  git tag dev/v8.0

# Mismatched tag: claim major=99 but the commit's meta.json has schemaVersion=8.
# It must be silently dropped (with stderr warning).
git tag prod/v99.0

out="$(bash "$S" 2>/dev/null | sort)"

expected="dev 7 2 dev/v7.2 assets-dev
dev 8 0 dev/v8.0 assets-dev
prod 7 10 prod/v7.10 assets
prod 8 0 prod/v8.0 assets"

assert_eq "selects winning tag per (env,major) with deploy dir" "$expected" "$out"

if printf '%s\n' "$out" | grep -q 'prod/v99.0'; then
  assert_eq "mismatched tag skipped" "skipped" "present"
else
  assert_eq "mismatched tag skipped" "skipped" "skipped"
fi

# Stderr must contain a warning for the mismatched tag.
err="$(bash "$S" 2>&1 >/dev/null)"
if printf '%s' "$err" | grep -q 'prod/v99.0'; then
  assert_eq "warning emitted for mismatch" "warned" "warned"
else
  assert_eq "warning emitted for mismatch" "warned" "missing"
fi

summary
