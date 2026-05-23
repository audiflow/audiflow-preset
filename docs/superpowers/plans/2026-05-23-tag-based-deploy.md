# Tag-based deployment Implementation Plan

> **Status (2026-05-23):** The `gh-pages`-branch-based deploy described in this plan (notably Task 7's `scripts/ci/rebuild-gh-pages.sh` and Task 9's `gh-pages` checkout + push) was superseded by the GitHub-Actions-sourced Pages deploy landed on branch `fix/pages-actions-source`. The script is now `scripts/ci/build-pages-tree.sh` (env var `BUILD_ALLOW_EMPTY`), and `deploy-pages.yml` uploads a `_site` artifact via `actions/upload-pages-artifact@v3` and publishes it via `actions/deploy-pages@v4` (no commit to `gh-pages`). Treat the Task 7 / Task 9 sections below as historical; the current spec is in `docs/superpowers/specs/2026-05-23-tag-based-deploy-design.md` and the live workflow in `.github/workflows/deploy-pages.yml`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-env source branches (`prod/v*`, `stg/v*`, `dev/v*`) with a two-branch + tag-driven model (`main` + `develop`, tags `{env}/v{schemaVersion}.{dataVersion}`) while keeping the existing `gh-pages` layout (`assets/v{N}/`, `assets-dev/v{N}/`).

**Architecture:** Three workflows. `bump-versions.yml` runs on push to `main`/`develop`, calls editor binary, commits bump, auto-tags `prod/...` or `dev/...`. `deploy-pages.yml` runs on those tag pushes, lists all matching tags, picks highest minor per `(env, major)`, rsyncs each tag's `presets/` into `gh-pages/{deployDir}/v{major}/`, full-replace. `validate.yml` runs on PR, downloads editor binary keyed by `presets/meta.json:.schemaVersion`. Shell helpers under `scripts/ci/` are pure-stdio and unit-tested with a small bash harness for TDD.

**Tech Stack:** GitHub Actions, bash, jq, `audiflow-editor` CLI (downloaded per run from `audiflow/audiflow-preset-editor` releases), bats-less bash test harness (zero external deps), `actionlint` for workflow lint.

---

## Spec

`docs/superpowers/specs/2026-05-23-tag-based-deploy-design.md`

## File structure

- Create:
  - `scripts/ci/lib.sh` — shared bash helpers (`require_cmd`, `read_schema_version`, `read_data_version`)
  - `scripts/ci/parse-tag.sh` — pure: reads tag name from `$1`, prints `env major minor` or exits 1
  - `scripts/ci/pick-winning-tags.sh` — pure: reads tag list from stdin, prints `env major minor tag` for the max-minor tag per `(env, major)`
  - `scripts/ci/bump-and-tag.sh` — orchestration: run editor `bump-versions`, commit if dirty, compute tag, push
  - `scripts/ci/select-deploy-targets.sh` — orchestration: enumerate local tags, run `pick-winning-tags.sh`, validate each tag's `schemaVersion`, emit deploy plan TSV
  - `scripts/ci/rebuild-gh-pages.sh` — orchestration: reads deploy plan, materializes `staging/` dir from worktrees, rsyncs into a `gh-pages/` checkout
  - `tests/scripts/run.sh` — bash test harness (no deps)
  - `tests/scripts/parse-tag_test.sh`
  - `tests/scripts/pick-winning-tags_test.sh`
  - `tests/scripts/select-deploy-targets_test.sh`
  - `tests/scripts/bump-and-tag_test.sh`
  - `.github/workflows/bump-versions.yml`
  - `docs/runbooks/2026-05-23-migrate-to-tags.md` — maintainer one-shot steps
- Modify:
  - `.github/workflows/deploy-pages.yml` — full rewrite
  - `.github/workflows/validate.yml` — replace branch-name parsing with `schemaVersion` lookup
  - `docs/architecture/multi-env-deploy.md`
  - `docs/architecture/editor-versioning.md`
  - `docs/development/change-workflow.md`
  - `docs/development/version-branch-rollout.md`
  - `CLAUDE.md`

Why this split: each shell helper is a single function with stdin/stdout contract → trivially unit-testable. Orchestration scripts stay thin; workflows stay thin. No logic lives only in workflow YAML.

---

## Task 1: Feature branch + test harness scaffolding

**Files:**
- Create: `tests/scripts/run.sh`
- Create: `tests/scripts/_assert.sh`
- Modify: `.gitignore` (append)

- [ ] **Step 1: Branch off main**

```bash
git fetch origin main
git checkout -b feat/tag-based-deploy origin/main
```

Expected: branch created at origin/main HEAD.

- [ ] **Step 2: Write the assertion helper**

Create `tests/scripts/_assert.sh`:

```bash
#!/usr/bin/env bash
# Tiny assertion lib for tests/scripts. No deps.
set -u

PASS=0
FAIL=0
FAILED_NAMES=()

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  FAIL %s\n    expected: %q\n    actual:   %q\n' "$name" "$expected" "$actual"
  fi
}

assert_exit() {
  local name="$1" expected_rc="$2" actual_rc="$3"
  if [ "$expected_rc" = "$actual_rc" ]; then
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
    printf '  FAIL %s (rc expected=%s actual=%s)\n' "$name" "$expected_rc" "$actual_rc"
  fi
}

summary() {
  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
  if [ "$FAIL" -ne 0 ]; then
    printf 'Failed: %s\n' "${FAILED_NAMES[*]}"
    exit 1
  fi
}
```

- [ ] **Step 3: Write the runner**

Create `tests/scripts/run.sh`:

```bash
#!/usr/bin/env bash
# Runs every *_test.sh under tests/scripts/. Each test file sources _assert.sh
# and calls summary at end.
set -eu
cd "$(dirname "$0")"

shopt -s nullglob
files=( *_test.sh )
if [ ${#files[@]} -eq 0 ]; then
  echo "no tests found"
  exit 0
fi

rc=0
for t in "${files[@]}"; do
  echo "== $t =="
  bash "$t" || rc=$?
done
exit "$rc"
```

- [ ] **Step 4: Ignore test scratch**

Append to `.gitignore`:

```
/tests/scripts/.tmp/
```

- [ ] **Step 5: Verify harness runs with zero tests**

Run:
```bash
chmod +x tests/scripts/run.sh
tests/scripts/run.sh
```
Expected: `no tests found` and exit 0.

- [ ] **Step 6: Commit**

```bash
git add tests/scripts/run.sh tests/scripts/_assert.sh .gitignore
git commit -m "chore: add bash test harness for ci scripts"
```

---

## Task 2: `scripts/ci/parse-tag.sh` (TDD)

**Files:**
- Create: `tests/scripts/parse-tag_test.sh`
- Create: `scripts/ci/parse-tag.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/parse-tag_test.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/parse-tag.sh"

run() { bash "$S" "$1" 2>/dev/null; }

assert_eq "prod simple"     "prod 7 0"  "$(run prod/v7.0)"
assert_eq "dev two-digit"   "dev 12 345" "$(run dev/v12.345)"
assert_eq "prod minor zero" "prod 8 0"  "$(run prod/v8.0)"

run_rc() { bash "$S" "$1" >/dev/null 2>&1; echo $?; }
assert_exit "missing env"       1 "$(run_rc v7.1)"
assert_exit "bad env"           1 "$(run_rc stg/v7.1)"
assert_exit "missing minor"     1 "$(run_rc prod/v7)"
assert_exit "non-numeric major" 1 "$(run_rc prod/vX.1)"
assert_exit "leading zero ok"   0 "$(run_rc prod/v07.1)"
assert_exit "trailing junk"     1 "$(run_rc prod/v7.1-rc1)"
assert_exit "no arg"            1 "$(run_rc '')"

summary
```

- [ ] **Step 2: Run test, verify it fails**

Run: `tests/scripts/run.sh`
Expected: all assertions FAIL (script does not exist) and exit 1.

- [ ] **Step 3: Implement `scripts/ci/parse-tag.sh`**

Create `scripts/ci/parse-tag.sh`:

```bash
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
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `chmod +x scripts/ci/parse-tag.sh && tests/scripts/run.sh`
Expected: `9 passed, 0 failed` and exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/ci/parse-tag.sh tests/scripts/parse-tag_test.sh
git commit -m "feat(ci): add parse-tag helper"
```

---

## Task 3: `scripts/ci/pick-winning-tags.sh` (TDD)

**Files:**
- Create: `tests/scripts/pick-winning-tags_test.sh`
- Create: `scripts/ci/pick-winning-tags.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/pick-winning-tags_test.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/pick-winning-tags.sh"

run() { printf '%s\n' "$@" | bash "$S" 2>/dev/null | sort; }

# Per (env, major) keep highest minor.
input1=(prod/v7.0 prod/v7.10 prod/v7.2 dev/v7.5 dev/v7.6 prod/v8.0)
expected1="dev 7 6 dev/v7.6
prod 7 10 prod/v7.10
prod 8 0 prod/v8.0"
assert_eq "max-minor across envs+majors" "$expected1" "$(run "${input1[@]}")"

# Numeric sort (not lexicographic): v7.10 > v7.2
input2=(prod/v7.2 prod/v7.10)
assert_eq "numeric sort 10>2" "prod 7 10 prod/v7.10" "$(run "${input2[@]}")"

# Invalid tags are silently dropped.
input3=(prod/v7.1 stg/v7.1 garbage prod/v7.2)
assert_eq "ignore invalid" "prod 7 2 prod/v7.2" "$(run "${input3[@]}")"

# Empty stdin -> empty stdout, exit 0.
assert_eq "empty input" "" "$(printf '' | bash "$S" 2>/dev/null)"

summary
```

- [ ] **Step 2: Run test, verify it fails**

Run: `tests/scripts/run.sh`
Expected: assertions FAIL.

- [ ] **Step 3: Implement `scripts/ci/pick-winning-tags.sh`**

Create `scripts/ci/pick-winning-tags.sh`:

```bash
#!/usr/bin/env bash
# Read tag names from stdin (one per line). For each (env, major) pair,
# emit the tag with the highest minor. Output format: "env major minor tag".
# Invalid tags are dropped silently. Output order is not guaranteed.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PARSE="$HERE/parse-tag.sh"

declare -A BEST_MINOR=()
declare -A BEST_TAG=()

while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  parsed="$(bash "$PARSE" "$tag" 2>/dev/null)" || continue
  read -r env major minor <<<"$parsed"
  key="${env}/${major}"
  if [ -z "${BEST_MINOR[$key]:-}" ] || [ "$minor" -gt "${BEST_MINOR[$key]}" ]; then
    BEST_MINOR[$key]="$minor"
    BEST_TAG[$key]="$tag"
  fi
done

for key in "${!BEST_MINOR[@]}"; do
  env="${key%%/*}"
  major="${key##*/}"
  printf '%s %s %s %s\n' "$env" "$major" "${BEST_MINOR[$key]}" "${BEST_TAG[$key]}"
done
```

Note: uses `-gt` (numeric `>`), but per project rules we prefer `<`. Rewrite as:

```bash
  if [ -z "${BEST_MINOR[$key]:-}" ] || [ "${BEST_MINOR[$key]}" -lt "$minor" ]; then
```

Final script body uses the `-lt` form. Replace the conditional accordingly.

- [ ] **Step 4: Run tests, verify they pass**

Run: `chmod +x scripts/ci/pick-winning-tags.sh && tests/scripts/run.sh`
Expected: `13 passed, 0 failed` (4 new + 9 prior).

- [ ] **Step 5: Commit**

```bash
git add scripts/ci/pick-winning-tags.sh tests/scripts/pick-winning-tags_test.sh
git commit -m "feat(ci): add pick-winning-tags helper"
```

---

## Task 4: `scripts/ci/lib.sh` (shared helpers)

**Files:**
- Create: `scripts/ci/lib.sh`

- [ ] **Step 1: Write the file**

Create `scripts/ci/lib.sh`:

```bash
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
```

- [ ] **Step 2: Smoke-test via shell**

Run:
```bash
chmod +x scripts/ci/lib.sh
bash -c '. scripts/ci/lib.sh; deploy_dir_for_env prod; deploy_dir_for_env dev'
```
Expected output:
```
assets
assets-dev
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ci/lib.sh
git commit -m "feat(ci): add lib.sh with shared helpers"
```

---

## Task 5: `scripts/ci/bump-and-tag.sh` (TDD with fixture repo)

**Files:**
- Create: `tests/scripts/bump-and-tag_test.sh`
- Create: `scripts/ci/bump-and-tag.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/bump-and-tag_test.sh`:

```bash
#!/usr/bin/env bash
# Smoke test of bump-and-tag.sh against a fake editor binary in a temp git repo.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
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

# Set up a git repo with a remote we can push to (bare).
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

# Expect: bot commit added, tag prod/v7.42 created and pushed.
last_msg="$(git log -1 --pretty=%s)"
assert_eq "bot commit subject" "chore: bump versions" "$last_msg"

tag_count="$(git tag -l 'prod/v7.42' | wc -l | tr -d ' ')"
assert_eq "tag created locally" "1" "$tag_count"

remote_tag="$(git --git-dir="$TMP/remote.git" tag -l 'prod/v7.42' | wc -l | tr -d ' ')"
assert_eq "tag pushed to remote" "1" "$remote_tag"

# Re-run with no presets change: should not commit, should not tag.
output2="$(BUMP_ENV=prod GIT_REMOTE=origin bash "$S" 2>&1)"
last_msg2="$(git log -1 --pretty=%s)"
assert_eq "no-op leaves last commit unchanged" "chore: bump versions" "$last_msg2"

summary
```

- [ ] **Step 2: Run test, verify it fails**

Run: `tests/scripts/run.sh`
Expected: bump-and-tag assertions FAIL (script missing).

- [ ] **Step 3: Implement `scripts/ci/bump-and-tag.sh`**

Create `scripts/ci/bump-and-tag.sh`:

```bash
#!/usr/bin/env bash
# Runs audiflow-editor bump-versions HEAD~1, commits "chore: bump versions"
# if anything changed, then tags ${BUMP_ENV}/v${schemaVersion}.${dataVersion}
# and pushes both commit and tag to ${GIT_REMOTE} (default: origin).
#
# Idempotent: if there is no diff after bump, no commit, no tag, no push.
# Requires: git, jq, audiflow-editor in PATH.
# Required env: BUMP_ENV (prod|dev)
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
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

# Configure committer identity (workflow-level config may not stick in scripts).
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
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `chmod +x scripts/ci/bump-and-tag.sh && tests/scripts/run.sh`
Expected: all assertions pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/ci/bump-and-tag.sh tests/scripts/bump-and-tag_test.sh
git commit -m "feat(ci): add bump-and-tag orchestrator"
```

---

## Task 6: `scripts/ci/select-deploy-targets.sh` (TDD)

**Files:**
- Create: `tests/scripts/select-deploy-targets_test.sh`
- Create: `scripts/ci/select-deploy-targets.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/select-deploy-targets_test.sh`:

```bash
#!/usr/bin/env bash
# Tests select-deploy-targets.sh against a fixture git repo with seeded tags.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/_assert.sh"

S="$ROOT/scripts/ci/select-deploy-targets.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
git init -q -b main repo
cd repo
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

make_commit 7 1 "v7.1";  git tag prod/v7.1; git tag dev/v7.1
make_commit 7 2 "v7.2";  git tag dev/v7.2
make_commit 7 10 "v7.10"; git tag prod/v7.10
make_commit 8 0 "v8.0";  git tag prod/v8.0; git tag dev/v8.0

# Add a mismatched tag: tag major=8 but presets/meta says schemaVersion=7.
git reset --hard HEAD~3   # back to v7.1 commit
git tag prod/v8.99 || true
git reset --hard main >/dev/null 2>&1 || true

# Run.
out="$(bash "$S" 2>/dev/null | sort)"

expected="dev 7 2 dev/v7.2 assets-dev
dev 8 0 dev/v8.0 assets-dev
prod 7 10 prod/v7.10 assets
prod 8 0 prod/v8.0 assets"

assert_eq "selects winning tag per (env,major) with deploy dir" "$expected" "$out"

# Confirm the mismatched tag (prod/v8.99 -> schemaVersion 7) was skipped.
if printf '%s\n' "$out" | grep -q 'prod/v8.99'; then
  assert_eq "mismatched tag skipped" "skipped" "present"
else
  assert_eq "mismatched tag skipped" "skipped" "skipped"
fi

summary
```

- [ ] **Step 2: Run test, verify it fails**

Run: `tests/scripts/run.sh`
Expected: assertions FAIL.

- [ ] **Step 3: Implement `scripts/ci/select-deploy-targets.sh`**

Create `scripts/ci/select-deploy-targets.sh`:

```bash
#!/usr/bin/env bash
# Emits the deploy plan as TSV-ish lines:
#   env major minor tag deployDir
# One line per (env, major) winning tag.
# Tags whose presets/meta.json:.schemaVersion disagrees with the tag's major are
# skipped with a ::warning:: line on stderr.
#
# Must be run inside a git repo where all relevant tags are fetched locally.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
PICK="$HERE/pick-winning-tags.sh"

require_cmd git
require_cmd jq

tag_list="$(git tag -l 'prod/v*.*' 'dev/v*.*')"

while read -r env major minor tag; do
  [ -z "${env:-}" ] && continue
  meta_json="$(git show "${tag}:presets/meta.json" 2>/dev/null || true)"
  if [ -z "$meta_json" ]; then
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
done < <(printf '%s\n' "$tag_list" | bash "$PICK")
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `chmod +x scripts/ci/select-deploy-targets.sh && tests/scripts/run.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/ci/select-deploy-targets.sh tests/scripts/select-deploy-targets_test.sh
git commit -m "feat(ci): add select-deploy-targets script"
```

---

## Task 7: `scripts/ci/rebuild-gh-pages.sh` (orchestration)

**Files:**
- Create: `scripts/ci/rebuild-gh-pages.sh`

No TDD here — the script is shell glue around `git worktree` and `rsync`. It is exercised end-to-end in the workflow integration in Task 9.

- [ ] **Step 1: Write the script**

Create `scripts/ci/rebuild-gh-pages.sh`:

```bash
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

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:?source repo path required}"
GHP="${2:?gh-pages checkout path required}"
[ -d "$SRC/.git" ] || { echo "$SRC is not a git repo" >&2; exit 1; }
[ -d "$GHP/.git" ] || { echo "$GHP is not a git checkout" >&2; exit 1; }

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"; cd "$SRC" && git worktree prune' EXIT

cd "$SRC"
git tag -l >/dev/null  # warm

bash "$HERE/select-deploy-targets.sh" | while read -r env major minor tag dir; do
  [ -z "${env:-}" ] && continue
  wt="$(mktemp -d)"
  git worktree add --quiet --detach "$wt" "$tag"
  target="$STAGING/$dir/v$major"
  mkdir -p "$target"
  rsync -a --delete "$wt/presets/" "$target/"
  git worktree remove --force "$wt"
done

# Sync staging into gh-pages root. --delete drops any tree without a backing tag.
rsync -a --delete \
  --exclude '/.git/' \
  --exclude '/.gitignore' \
  --exclude '/CNAME' \
  --exclude '/README.md' \
  "$STAGING/" "$GHP/"
```

- [ ] **Step 2: Smoke-test against the current repo**

Run:
```bash
chmod +x scripts/ci/rebuild-gh-pages.sh
tmp_src="$(mktemp -d)"
tmp_ghp="$(mktemp -d)"
git clone --quiet . "$tmp_src"
(cd "$tmp_src" && git fetch --quiet origin '+refs/tags/*:refs/tags/*' || true)
git clone --quiet --branch gh-pages . "$tmp_ghp" 2>/dev/null || (
  mkdir -p "$tmp_ghp" && cd "$tmp_ghp" && git init -q -b gh-pages && \
  git commit -q --allow-empty -m init
)
scripts/ci/rebuild-gh-pages.sh "$tmp_src" "$tmp_ghp"
ls "$tmp_ghp" || true
```
Expected: command exits 0. If no `prod/v*` or `dev/v*` tags exist yet, the staging is empty and the rsync clears every dir from `$tmp_ghp` except the excluded files — this is correct pre-migration behavior. Do NOT run this against the real `gh-pages` clone.

- [ ] **Step 3: Commit**

```bash
git add scripts/ci/rebuild-gh-pages.sh
git commit -m "feat(ci): add rebuild-gh-pages orchestrator"
```

---

## Task 8: `.github/workflows/bump-versions.yml`

**Files:**
- Create: `.github/workflows/bump-versions.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/bump-versions.yml`:

```yaml
name: Bump versions + tag

on:
  push:
    branches: [main, develop]
    paths:
      - "presets/**.json"
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: bump-${{ github.ref_name }}
  cancel-in-progress: false

jobs:
  bump-and-tag:
    if: github.actor != 'audiflow-ci-bot[bot]'
    runs-on: ubuntu-latest
    steps:
      - name: Generate CI bot token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ vars.CI_BOT_APP_ID }}
          private-key: ${{ secrets.CI_BOT_PRIVATE_KEY }}

      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2
          token: ${{ steps.app-token.outputs.token }}

      - name: Resolve schema major
        id: schema
        run: |
          major="$(jq -r .schemaVersion presets/meta.json)"
          echo "major=${major}" >> "$GITHUB_OUTPUT"

      - name: Download audiflow-editor
        env:
          MAJOR: ${{ steps.schema.outputs.major }}
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release download "v${MAJOR}" \
            --repo audiflow/audiflow-preset-editor \
            --pattern 'audiflow-editor-x86_64-unknown-linux-gnu' \
            --output /usr/local/bin/audiflow-editor
          chmod +x /usr/local/bin/audiflow-editor

      - name: Bump and tag
        env:
          BUMP_ENV: ${{ github.ref_name == 'main' && 'prod' || 'dev' }}
          GIT_REMOTE: origin
        run: bash scripts/ci/bump-and-tag.sh
```

- [ ] **Step 2: Lint with actionlint**

Run: `actionlint .github/workflows/bump-versions.yml`
Expected: exit 0 with no findings.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/bump-versions.yml
git commit -m "ci: add bump-versions + tag workflow"
```

---

## Task 9: `.github/workflows/deploy-pages.yml` (rewrite)

**Files:**
- Modify: `.github/workflows/deploy-pages.yml`

- [ ] **Step 1: Replace the file entirely**

Overwrite `.github/workflows/deploy-pages.yml`:

```yaml
name: Deploy to Pages

on:
  push:
    tags:
      - "prod/v*.*"
      - "dev/v*.*"
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: deploy-pages
  cancel-in-progress: false

jobs:
  rebuild:
    runs-on: ubuntu-latest
    steps:
      - name: Generate CI bot token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ vars.CI_BOT_APP_ID }}
          private-key: ${{ secrets.CI_BOT_PRIVATE_KEY }}

      - name: Checkout main (workflow + scripts)
        uses: actions/checkout@v4
        with:
          ref: main
          fetch-depth: 1
          path: src
          token: ${{ steps.app-token.outputs.token }}

      - name: Fetch all matching tags
        working-directory: src
        run: |
          git fetch --tags --quiet origin \
            "+refs/tags/prod/*:refs/tags/prod/*" \
            "+refs/tags/dev/*:refs/tags/dev/*"

      - name: Checkout gh-pages
        id: checkout-ghpages
        uses: actions/checkout@v4
        with:
          ref: gh-pages
          path: gh-pages
          token: ${{ steps.app-token.outputs.token }}
        continue-on-error: true

      - name: Initialize gh-pages if needed
        if: steps.checkout-ghpages.outcome == 'failure'
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
          GITHUB_REPOSITORY: ${{ github.repository }}
        run: |
          rm -rf gh-pages
          mkdir gh-pages && cd gh-pages
          git init -b gh-pages
          git config user.name  "audiflow-ci-bot[bot]"
          git config user.email "audiflow-ci-bot[bot]@users.noreply.github.com"
          git commit --allow-empty -m "chore: initialize gh-pages"
          git remote add origin \
            "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

      - name: Rebuild gh-pages from tags
        run: bash src/scripts/ci/rebuild-gh-pages.sh src gh-pages

      - name: Commit + push gh-pages
        working-directory: gh-pages
        env:
          TRIGGER: ${{ github.ref_name }}
        run: |
          git config user.name  "audiflow-ci-bot[bot]"
          git config user.email "audiflow-ci-bot[bot]@users.noreply.github.com"
          git add -A
          if git diff --cached --quiet; then
            echo "deploy-pages: no changes"
            exit 0
          fi
          git commit -m "deploy: rebuild from tags @ ${TRIGGER}"
          for attempt in 1 2 3; do
            git push origin gh-pages && exit 0
            echo "push conflict (attempt ${attempt}); rebasing"
            git pull --rebase origin gh-pages
          done
          echo "::error::failed to push to gh-pages after 3 attempts"
          exit 1
```

- [ ] **Step 2: Lint**

Run: `actionlint .github/workflows/deploy-pages.yml`
Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/deploy-pages.yml
git commit -m "ci: rewrite deploy-pages for tag-driven full rebuild"
```

---

## Task 10: `.github/workflows/validate.yml` (rewrite)

**Files:**
- Modify: `.github/workflows/validate.yml`

- [ ] **Step 1: Read the existing file**

Run: `cat .github/workflows/validate.yml`
Inspect to confirm current trigger and steps; copy any non-obvious bits (caching, permissions) into the new version.

- [ ] **Step 2: Replace the file**

Overwrite `.github/workflows/validate.yml`:

```yaml
name: Validate presets

on:
  pull_request:
    branches: [main, develop]
    paths:
      - "presets/**"
      - "schema/**"
      - ".github/workflows/validate.yml"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout PR head
        uses: actions/checkout@v4

      - name: Resolve schema major
        id: schema
        run: |
          major="$(jq -r .schemaVersion presets/meta.json)"
          echo "major=${major}" >> "$GITHUB_OUTPUT"

      - name: Download audiflow-editor
        env:
          MAJOR: ${{ steps.schema.outputs.major }}
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release download "v${MAJOR}" \
            --repo audiflow/audiflow-preset-editor \
            --pattern 'audiflow-editor-x86_64-unknown-linux-gnu' \
            --output /usr/local/bin/audiflow-editor
          chmod +x /usr/local/bin/audiflow-editor

      - name: Validate
        run: audiflow-editor validate presets/
```

- [ ] **Step 3: Lint**

Run: `actionlint .github/workflows/validate.yml`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/validate.yml
git commit -m "ci: validate uses presets/meta.json schemaVersion (not branch name)"
```

---

## Task 11: Docs updates

**Files:**
- Modify: `docs/architecture/multi-env-deploy.md`
- Modify: `docs/architecture/editor-versioning.md`
- Modify: `docs/development/change-workflow.md`
- Modify: `docs/development/version-branch-rollout.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Rewrite `docs/architecture/multi-env-deploy.md`**

Replace its content with:

```markdown
# Multi-environment deployment

This repo serves prod and dev environments across multiple schema majors from a single GitHub Pages deployment. Each deploy is driven by a git tag; old majors stay published as long as their tags exist.

## Source model

Two long-lived branches:

| Branch | Role |
|--------|------|
| `main` | Promoted/stable. `prod/v{M}.{m}` tags cut here automatically. |
| `develop` | Working branch for the current schema major. `dev/v{M}.{m}` tags cut here automatically. |

`presets/` and `schema/` live at the repo root on both branches. There is no per-env or per-version source directory.

## Tag convention

`{env}/v{schemaVersion}.{dataVersion}` where `env ∈ {prod, dev}`.

- `schemaVersion` is read from `presets/meta.json` (sole SoT for schema major).
- `dataVersion` is read from `presets/meta.json`, bumped automatically by CI on every push.
- Same commit may carry multiple env tags (e.g. `prod/v7.10` and `dev/v7.10`) when promotion produces identical content.

## gh-pages layout

```
gh-pages branch:
  assets/v7/       <- highest-minor prod/v7.* tag
  assets/v8/       <- highest-minor prod/v8.* tag
  assets-dev/v7/   <- highest-minor dev/v7.* tag
  assets-dev/v8/   <- highest-minor dev/v8.* tag
```

## How it works

- Push to `main` or `develop` (touching `presets/**.json`) → `bump-versions.yml` runs `audiflow-editor bump-versions`, commits, and tags `{env}/v{schemaVersion}.{dataVersion}`.
- That tag push → `deploy-pages.yml` enumerates all matching tags, picks the highest minor per `(env, major)`, and rebuilds the full `gh-pages` tree from the winning tags' `presets/` content. Directories without a backing tag (e.g. legacy `assets-stg/*`) are removed.

## Schema major lifecycle

1. Schema v7 is current: `presets/meta.json:.schemaVersion = 7`.
2. Schema v8 ships: bump `schemaVersion` to 8 on `develop`, migrate all presets, get the editor `v8` release ready, push.
3. Bug fix for v7: check out an old `prod/v7.x` tag, branch off, fix, manually tag `prod/v7.{x+1}`, push the tag.
4. Both `/assets/v7/` and `/assets/v8/` are served concurrently.
5. Sunset v7: delete every `prod/v7.*` and `dev/v7.*` tag; next deploy run drops the directory.

## Branch + tag protection

- `main`, `develop`: PR required, `validate` must pass, no force-push, no delete.
- `gh-pages`: bot-only push.
- Tags `prod/**`, `dev/**`: protected ruleset; only maintainers and `audiflow-ci-bot[bot]` can create; no delete, no overwrite.

## GitHub Pages configuration

Pages deploys from the `gh-pages` branch at `/` (root). Set in Settings > Pages.
```

- [ ] **Step 2: Rewrite `docs/development/change-workflow.md`**

Replace its content with:

```markdown
# Change workflow

## Branches

- Edit on `develop` (current schema major, dev environment).
- Promote to `main` via PR (= prod environment).
- Old majors are tag-only; see hotfix section below.

## Adding a new preset

1. Check out `develop`: `git checkout develop && git pull`.
2. Create directory: `presets/{presetId}/`.
3. Create `presets/{presetId}/meta.json` (required: `dataVersion`, `id`, `feedUrls`, `playlists`).
4. Create `presets/{presetId}/playlists/{playlistId}.json` for each playlist.
5. Add a `PresetSummary` entry to `presets/meta.json:.presets` (matching `id`, `dataVersion`, `displayName`, `feedUrlHint`, `playlistCount`).
6. Validate locally: `schema/scripts/validate.sh presets/**/*.json`.
7. Push (or open PR if `develop` is protected). CI runs `validate.yml`, then `bump-versions.yml` cuts a `dev/v{M}.{m}` tag and deploys.

## Modifying an existing preset

1. Check out the relevant working branch (`develop` for current major; a hotfix branch off an old tag for old majors).
2. Edit JSON under `presets/{presetId}/`.
3. Do NOT manually bump `dataVersion` — CI handles it.
4. Validate locally.
5. Push or open PR.

## Adding a playlist to an existing preset

1. Create `presets/{presetId}/playlists/{newPlaylistId}.json`.
2. Add `{newPlaylistId}` to `presets/{presetId}/meta.json:.playlists`.
3. Update `playlistCount` in `presets/meta.json` for that preset.
4. Validate locally.

## Promoting dev to prod

```
develop -> PR -> main
```

The merge commit on `main` is auto-tagged `prod/v{M}.{m}` and deployed.

## Hotfix on an old schema major

1. List tags for the target major: `git tag -l 'prod/v6.*'`.
2. Check out the latest one: `git checkout prod/v6.42`.
3. Branch: `git checkout -b hotfix/v6-fix-X`.
4. Apply fix; bump `dataVersion` manually (no CI on hotfix branches): `jq '.dataVersion += 1' presets/meta.json | sponge presets/meta.json` (and update affected per-preset `dataVersion`s if you touched them).
5. Commit; tag with the next free minor: `git tag prod/v6.43`.
6. Push the tag (not the branch): `git pull --tags && git push origin prod/v6.43`. Push fails if `prod/v6.43` already exists — re-fetch and pick a higher minor.

## Schema major bump

See `docs/development/version-branch-rollout.md`.

## CI behavior

- **PR to `main` or `develop`** (`validate.yml`): downloads `audiflow-editor` matching `presets/meta.json:.schemaVersion` on the PR head, runs `validate`.
- **Push to `main` or `develop`** (`bump-versions.yml`): bumps `dataVersion`, commits, tags `{env}/v{M}.{d}`, pushes tag.
- **Push of any `prod/v*.*` or `dev/v*.*` tag** (`deploy-pages.yml`): rebuilds `gh-pages` from all matching tags (highest minor per env+major wins).
```

- [ ] **Step 3: Rewrite `docs/development/version-branch-rollout.md`**

Replace its content with:

```markdown
# Schema major rollout

Operational runbook for landing a new schema major (e.g. v7 -> v8).

## CI contract

- `bump-versions.yml`: triggers on push to `main`/`develop`. Reads `presets/meta.json:.schemaVersion`, downloads `audiflow-editor` from editor release `v{N}`, bumps `dataVersion`, commits, and tags `{env}/v{N}.{dataVersion}`.
- `validate.yml`: triggers on PR to `main`/`develop`. Same `schemaVersion`-keyed download.
- `deploy-pages.yml`: triggers on tag push matching `prod/v*.*` or `dev/v*.*`. Full rebuild.

## Preconditions

1. `audiflow-preset-editor` has a `vN` Release with the `audiflow-editor-x86_64-unknown-linux-gnu` asset.
2. A feature branch (conventionally `feat/vN`) carries:
   - `presets/meta.json:.schemaVersion` set to N
   - `schema/*.schema.json` vendored from the editor SSoT
   - All `presets/**` migrated to the new schema

## Recommended flow (PR-gated)

1. Land `feat/vN` on `develop` via PR. `validate.yml` runs with the `vN` editor binary.
2. On merge, `bump-versions.yml` cuts `dev/v{N}.{d}` and `deploy-pages.yml` publishes `assets-dev/v{N}/`.
3. Promote to prod when stable: PR `develop` → `main`. Merge cuts `prod/v{N}.{d}` and publishes `assets/v{N}/`.

## Anti-patterns

- Don't create a standalone "bump-only" commit for `schemaVersion` or `dataVersion` — `dataVersion` is bot-managed; `schemaVersion` belongs on `feat/vN`.
- Don't push tags manually for the normal flow — CI handles it. Manual tags are only for old-major hotfixes (see change-workflow.md).
- Don't create `feat/vN` before the editor `vN` release exists.
```

- [ ] **Step 4: Update `docs/architecture/editor-versioning.md`**

Replace the "Data repo CI consumption" section with:

```markdown
### Data repo CI consumption

The data repo's workflows download the editor binary keyed by the schema major
read from `presets/meta.json:.schemaVersion`:

```yaml
- run: |
    major="$(jq -r .schemaVersion presets/meta.json)"
    gh release download "v${major}" \
      --repo audiflow/audiflow-preset-editor \
      --pattern 'audiflow-editor-x86_64-unknown-linux-gnu' \
      --output audiflow-editor
    chmod +x audiflow-editor
- run: ./audiflow-editor validate presets/
- run: ./audiflow-editor bump-versions HEAD~1
```

No Rust toolchain, no clone, no `cargo build` required. Branch name is not used.
```

Leave the rest of the file intact.

- [ ] **Step 5: Update `CLAUDE.md`**

Replace the "Branch and deployment model" section with:

```markdown
## Branch and deployment model

Two long-lived branches:

| Branch | Role |
|--------|------|
| `main` | Promoted/stable. Auto-tagged `prod/v{schemaVersion}.{dataVersion}` on each push. |
| `develop` | Current-major working branch. Auto-tagged `dev/v{schemaVersion}.{dataVersion}` on each push. |

`presets/` and `schema/` live at the repo root on both branches.

Deployment is driven by tags, not branches. `deploy-pages.yml` rebuilds the entire `gh-pages` tree on each tag push; per `(env, major)`, the highest-minor tag wins:

| Tag | Deploy path | URL |
|-----|-------------|-----|
| `prod/v7.*` (max minor) | `/assets/v7/` | `audiflow.github.io/audiflow-preset/assets/v7/` |
| `dev/v7.*` (max minor) | `/assets-dev/v7/` | `audiflow.github.io/audiflow-preset/assets-dev/v7/` |
| `prod/v8.*` (max minor) | `/assets/v8/` | ... |

Promotion: `develop` -> PR -> `main`.

Old-major hotfix: check out an old tag, branch, fix, tag the next free minor manually.
```

Also update the "File layout" section to reflect single `presets/` and `schema/` at root (drop the env-branch table). Leave non-deployment sections (responsibilities, validation, references) intact.

- [ ] **Step 6: Commit**

```bash
git add docs/architecture/multi-env-deploy.md docs/architecture/editor-versioning.md \
        docs/development/change-workflow.md docs/development/version-branch-rollout.md \
        CLAUDE.md
git commit -m "docs: update for tag-based deploy model"
```

---

## Task 12: Migration runbook

**Files:**
- Create: `docs/runbooks/2026-05-23-migrate-to-tags.md`

- [ ] **Step 1: Write the runbook**

Create `docs/runbooks/2026-05-23-migrate-to-tags.md`:

```markdown
# Migration: per-env branches -> tag-driven deploy

Run these steps after the PR adding workflows + docs has merged to `main`.

## 0. Preflight

```bash
# Verify editor v7 release has linux-x64 binary
gh release view v7 --repo audiflow/audiflow-preset-editor \
  --json assets -q '.assets[].name' | grep audiflow-editor-x86_64-unknown-linux-gnu

# Record current gh-pages tree for the diff check in step 4
git clone --depth 1 --branch gh-pages \
  https://github.com/audiflow/audiflow-preset.git /tmp/gh-pages-before

# Disable the new tag-triggered deploy temporarily to avoid surprise runs.
# Edit .github/workflows/deploy-pages.yml on main and comment out the `push.tags`
# trigger, leaving only workflow_dispatch. Commit + push. We re-enable in step 4.
```

## 1. Seed presets/ on main

```bash
git fetch origin
git checkout main
git pull --ff-only

# Replace presets/ and schema/ with prod/v7 contents.
git checkout origin/prod/v7 -- presets/ schema/
git status   # review
git add presets/ schema/
git commit -m "chore: seed presets/schema from prod/v7"
git push origin main
```

## 2. Create develop

```bash
git checkout -b develop main
git push -u origin develop

# Overlay dev/v7 contents on top of main.
git checkout origin/dev/v7 -- presets/ schema/
git status   # review delta (should match dev-vs-prod)
git add presets/ schema/
git commit -m "chore: seed presets/schema from dev/v7"
git push origin develop
```

## 3. Cut initial tags manually

These will be the "starting" tags; subsequent pushes auto-tag.

```bash
# Prod
git checkout main
maj="$(jq -r .schemaVersion presets/meta.json)"
data="$(jq -r .dataVersion presets/meta.json)"
git tag "prod/v${maj}.${data}"
git push origin "prod/v${maj}.${data}"

# Dev
git checkout develop
maj="$(jq -r .schemaVersion presets/meta.json)"
data="$(jq -r .dataVersion presets/meta.json)"
git tag "dev/v${maj}.${data}"
git push origin "dev/v${maj}.${data}"
```

## 4. First deploy + diff check

```bash
# Re-enable the push.tags trigger in deploy-pages.yml (undo step 0 change).
gh workflow run deploy-pages.yml --ref main
# Wait for completion.

# Diff against pre-migration snapshot.
git clone --depth 1 --branch gh-pages \
  https://github.com/audiflow/audiflow-preset.git /tmp/gh-pages-after
diff -r --brief /tmp/gh-pages-before /tmp/gh-pages-after
```

Expected diff: only `assets-stg/*` removed. Anything else aborts the migration; investigate before continuing.

Rollback if needed:

```bash
# Restore prior gh-pages
cd /tmp/gh-pages-before
git push --force origin HEAD:gh-pages
```

## 5. Delete old source branches

After step 4 is clean:

```bash
for b in $(git ls-remote --heads origin \
  | awk '/refs\/heads\/(prod|stg|dev)\/v[0-9]+$/ {print $2}' \
  | sed 's@refs/heads/@@'); do
  echo "deleting origin/$b"
  git push origin --delete "$b"
done

# Also clean up stale feat/* and chore/* if appropriate (review first):
git ls-remote --heads origin | awk '/refs\/heads\/(feat|chore)\// {print $2}'
```

## 6. Update branch protection

In GitHub Settings > Rulesets:

- Remove rules targeting `prod/**`, `stg/**`, `dev/**`, `feat/**`.
- Add rule for `main` and `develop`: require PR, require `validate` status check, block force-push and deletion.
- Add tag protection rule for `prod/**` and `dev/**`: restrict creators to maintainers + `audiflow-ci-bot[bot]`; block deletion and update.

## 7. Notify editor team

The `audiflow-preset-editor` workflow now points at `develop` (current major) instead of `dev/vN`. Update the editor's branch-pick UI and docs accordingly.
```

- [ ] **Step 2: Commit**

```bash
git add docs/runbooks/2026-05-23-migrate-to-tags.md
git commit -m "docs: add tag-migration runbook"
```

---

## Task 13: Open PR to main

- [ ] **Step 1: Final sanity**

Run:
```bash
tests/scripts/run.sh
actionlint .github/workflows/*.yml
git status
```
Expected: tests pass, actionlint clean, no untracked changes.

- [ ] **Step 2: Push branch**

```bash
git push -u origin feat/tag-based-deploy
```

- [ ] **Step 3: Open PR**

```bash
gh pr create --base main --head feat/tag-based-deploy \
  --title "feat: tag-driven deploy preserving gh-pages layout" \
  --body "$(cat <<'EOF'
## Summary

- Replace per-env source branches with `main` + `develop` + auto-tagged `{env}/v{schemaVersion}.{dataVersion}`.
- `bump-versions.yml` (new): bumps dataVersion on push, auto-tags.
- `deploy-pages.yml` (rewrite): tag-triggered full rebuild; highest-minor tag per (env,major) wins.
- `validate.yml` (rewrite): reads schemaVersion from `presets/meta.json` instead of branch name.
- Shell helpers under `scripts/ci/` with bash test harness under `tests/scripts/`.
- Docs + migration runbook updated.

Spec: `docs/superpowers/specs/2026-05-23-tag-based-deploy-design.md`.
Plan: `docs/superpowers/plans/2026-05-23-tag-based-deploy.md`.
Migration runbook: `docs/runbooks/2026-05-23-migrate-to-tags.md`.

## Test plan

- [ ] `tests/scripts/run.sh` green
- [ ] `actionlint .github/workflows/*.yml` clean
- [ ] After merge, follow runbook step-by-step on a maintenance window
- [ ] Verify `gh-pages` diff matches expectation (only `assets-stg/*` removed)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed.

---

## Self-review

- **Spec coverage**
  - Source model (main + develop, presets/ at root) → Task 11 docs + runbook in Task 12.
  - Versioning model (schemaVersion as Major, dataVersion as minor) → Tasks 5, 8, 10.
  - Tag convention `{env}/v{M}.{m}` → Tasks 2, 5, 6.
  - Auto-tagging on push → Tasks 5, 8.
  - Manual hotfix tag flow → Task 11 (change-workflow.md).
  - bump-versions.yml → Task 8.
  - deploy-pages.yml (full rebuild, tag-trigger) → Tasks 6, 7, 9.
  - validate.yml (schemaVersion-keyed) → Task 10.
  - schemaVersion/major mismatch warning → Task 6.
  - Branch + tag protection → Task 12 runbook step 6.
  - Migration plan → Task 12.
  - Risks (no per-semver mirror, tag flood, concurrency, first commit, hotfix collision, editor write surface) → documented in spec; runbook + change-workflow address operational ones.

- **Placeholder scan:** none — every step contains the actual content.

- **Type/name consistency:**
  - `BUMP_ENV`, `GIT_REMOTE` env vars consistent across Task 5 script and Task 8 workflow.
  - `deploy_dir_for_env` defined once in `lib.sh` (Task 4); used by `select-deploy-targets.sh` (Task 6).
  - Tag pattern `{env}/v{M}.{m}` consistent across `parse-tag.sh`, `pick-winning-tags.sh`, workflows.

Plan complete and saved to `docs/superpowers/plans/2026-05-23-tag-based-deploy.md`.
