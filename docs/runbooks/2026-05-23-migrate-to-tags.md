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
