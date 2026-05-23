# Tag-based deployment, preserving GitHub Pages layout

Date: 2026-05-23
Status: Approved (design), awaiting implementation plan

## Goal

Migrate from a many-env-branch source model (`prod/v{N}`, `stg/v{N}`, `dev/v{N}`, ...) to a two-branch + tag-driven model, while preserving the existing GitHub Pages directory layout (`assets/v{N}/`, `assets-dev/v{N}/`). Each deploy uploads a Pages artifact via GitHub Actions (`actions/upload-pages-artifact` + `actions/deploy-pages`); no persistent deploy branch is used. Pages source is set to "GitHub Actions".

> Note: an earlier revision of this design kept a `gh-pages` branch as the deploy artifact. That branch-based deploy was superseded by the Actions-sourced Pages deploy in `fix/pages-actions-source`; the sections below describe the current model.

## Out of scope

- Schema authoring workflow (still owned by `audiflow-preset-editor`).
- Editor binary release model (`vN` mutable tag on the editor repo) is reused unchanged.
- App-side consumption logic (`audiflow` app).

## Source model

Branches (live, mutable):

| Branch | Role |
|--------|------|
| `main` | Promoted/stable. `prod/*` tags are cut here. |
| `develop` | Working branch for the current schema major. `dev/*` tags are cut here. |

All previous `prod/v*`, `stg/v*`, `dev/v*`, and `feat/*-v*` branches are deleted after migration. `stg` is abolished entirely.

Repo contents at HEAD of `main`/`develop`:

```
presets/                    # single tree
  meta.json                 # root index with schemaVersion + dataVersion
  {presetId}/
    meta.json
    playlists/{playlistId}.json
schema/                     # vendored schema for the current schemaVersion
.github/workflows/          # CI
docs/                       # docs (current location preserved)
```

There is no per-env or per-version directory split on the source side. The branch determines which env tag will be cut; the snapshot at the commit determines the schema major.

## Versioning model

Two existing version fields combine into the tag:

| Field | Where | Bumped by | Meaning |
|-------|-------|-----------|---------|
| `schemaVersion` | `presets/meta.json` (root) | Manually, on schema break | Tag **Major** |
| `dataVersion` | `presets/meta.json` (root) + each preset's `meta.json` | `audiflow-editor bump-versions` in CI, every push | Tag **minor** |

Tag format: `{env}/v{schemaVersion}.{dataVersion}`, where `env ∈ {prod, dev}`.

Examples: `prod/v7.42`, `dev/v7.43`, `prod/v8.0`.

`schemaVersion` is the sole source of truth for the schema major. `schema/VERSION` is removed (or kept only as a build cache, never read by CI).

## Tagging policy

Auto-tagging is the default. Manual tagging is reserved for old-major hotfixes.

### Auto (normal path)

After each successful `bump-versions` commit, the same workflow run creates and pushes the tag:

- On `main`: `prod/v${schemaVersion}.${dataVersion}`
- On `develop`: `dev/v${schemaVersion}.${dataVersion}`

The tag points to the bot's bump commit (or the original commit if `bump-versions` produced no diff).

Promotion = PR merge `develop -> main`. The resulting merge commit gets a `prod/...` tag automatically.

### Manual (old-major hotfix)

1. `git checkout {prod,dev}/v{M}.{m}` (an existing old-major tag).
2. Branch off, fix, commit.
3. `git tag {env}/v{M}.{m+k}` and `git push origin {env}/v{M}.{m+k}` (where `m+k` is the next free minor for that env+major; the operator picks it).
4. Branch may be discarded after tag is pushed; the tag is the artifact.

## CI workflows

### `bump-versions.yml` (new, replaces today's bump step)

- Trigger: `push` to `[main, develop]`, paths `presets/**.json`.
- Skip if actor is `audiflow-ci-bot[bot]`.
- Steps:
  1. Checkout with `fetch-depth: 2`.
  2. `major=$(jq -r .schemaVersion presets/meta.json)`.
  3. Download editor binary: `gh release download v${major} --repo audiflow/audiflow-preset-editor --pattern audiflow-editor-x86_64-unknown-linux-gnu`.
  4. `audiflow-editor bump-versions HEAD~1` (skip on first commit).
  5. `git add presets/ && git commit -m "chore: bump versions"` (if dirty).
  6. Push commit.
  7. `new_data=$(jq -r .dataVersion presets/meta.json)`.
  8. `env=prod` (if branch == main) or `env=dev` (if branch == develop).
  9. `git tag ${env}/v${major}.${new_data}` on the latest commit.
  10. `git push origin ${env}/v${major}.${new_data}`.
- Concurrency: per branch (`bump-${ref_name}`).
- Permissions: `contents: write` via CI bot app token.

### `deploy-pages.yml` (rewritten, full rebuild)

- Trigger: `push` to tags matching `prod/v*.*` or `dev/v*.*`, plus `workflow_dispatch`.
- Concurrency group: `deploy-pages` (single global; serializes all tag pushes).
- Algorithm:
  1. Checkout `main` (for workflow + helper scripts only).
  2. `git fetch --tags --depth=1`.
  3. List all tags matching `^(prod|dev)/v[0-9]+\.[0-9]+$`. Semver-aware sort.
  4. Group by `(env, major)`; pick the tag with the highest `minor` per group.
  5. For each winning tag:
     - `git worktree add /tmp/wt-${env}-${major} ${tag}`.
     - Read `schemaVersion` from that worktree's `presets/meta.json`.
     - If `schemaVersion != major` from tag, emit `::warning::` and skip.
     - Stage: `rsync -a /tmp/wt-${env}-${major}/presets/ _site/${deployDir}/v${major}/`, where `deployDir = assets` (prod) or `assets-dev` (dev).
  6. Upload `_site/` via `actions/upload-pages-artifact@v3`.
  7. In a separate `deploy` job (needs: build), publish via `actions/deploy-pages@v4` with `environment: github-pages`. The job requires `pages: write` and `id-token: write`.
  8. No persistent deploy branch is written; each run replaces the live tree atomically. Directories without a backing tag (e.g. legacy `assets-stg/*`) simply do not appear in the new artifact.

### `validate.yml` (revised)

- Trigger: `pull_request` to `[main, develop]`, paths `presets/**`, `schema/**`.
- Steps:
  1. Checkout PR HEAD.
  2. `major=$(jq -r .schemaVersion presets/meta.json)`.
  3. Download editor binary for `v${major}`.
  4. `audiflow-editor validate presets/`.
- Branch-name parsing is removed.

## Branch + tag protection

- `main`, `develop`: PR required, `validate` must pass, no force-push, no delete.
- Tags `prod/**`, `dev/**`: GitHub tag protection rule -- tagger must be a maintainer or `audiflow-ci-bot[bot]`. Once pushed, immutable (no delete, no move).
- No `gh-pages` branch: Pages source is "GitHub Actions"; `deploy-pages.yml` uploads an artifact and `actions/deploy-pages` publishes it.

## Migration plan

Executed by a maintainer in this order:

1. Land design + workflows on `main`:
   - This spec.
   - New `bump-versions.yml`, `validate.yml`, `deploy-pages.yml`.
   - Updated docs (`multi-env-deploy.md`, `change-workflow.md`, `version-branch-rollout.md`, `editor-versioning.md`, `CLAUDE.md`).
2. Seed branches:
   - On `main`: replace `presets/` and `schema/` with the contents of current `prod/v7` HEAD (single commit, "chore: seed presets from prod/v7"). Workflows + docs from this PR remain.
   - Create `develop` from `main` (post-seed), then on `develop`: overlay `presets/` and `schema/` from current `dev/v7` HEAD (single commit, "chore: seed presets from dev/v7"). This keeps `develop` ahead of `main` exactly by the dev-vs-prod delta.
3. Initial tagging (one-shot, manual):
   - On `main`: `git tag prod/v$(jq -r .schemaVersion presets/meta.json).$(jq -r .dataVersion presets/meta.json) && git push --tags`.
   - On `develop`: `git tag dev/v$(jq -r .schemaVersion presets/meta.json).$(jq -r .dataVersion presets/meta.json) && git push --tags`.
4. Switch GitHub Pages source from "Deploy from a branch" (`gh-pages` / `/`) to "GitHub Actions" in Settings > Pages. Trigger `deploy-pages.yml` once via `workflow_dispatch` and verify both `build` and `deploy` jobs succeed. Spot-check the deployed Pages URL (`curl -I https://audiflow.github.io/audiflow-preset/assets/v7/presets/meta.json` should return `200`). Any failure aborts the migration and triggers rollback.
5. Delete the legacy `gh-pages` branch only after step 4 succeeds (`git push origin --delete gh-pages`). Delete old source branches: `prod/v*`, `stg/v*`, `dev/v*`, stale `feat/*-v*`, `chore/rename-editor-repo-*`.
6. Update branch protection rulesets to cover `main`, `develop` only; remove old env-branch rules.

Rollback: revert the `deploy-pages.yml` change on `main` and switch the Pages source back to "Deploy from a branch" (`gh-pages` / `/`). Do this before step 5; once `gh-pages` is deleted the branch-based fallback is unavailable without restoring the branch from a local clone or the reflog within GitHub's retention window. Old source branches restored similarly if needed.

## Risks and accepted limitations

- **No per-semver immutable mirror.** Each `(env, major)` dir in the live Pages deploy always reflects the highest-minor tag's content. Historical data is recoverable only via repo tags. Acceptable per stated requirement.
- **Tag flood.** Every `presets/` push to `main` or `develop` produces a tag. Acceptable: tags are cheap and serve as the audit log that branch history previously provided.
- **Concurrent pushes.** The single global concurrency group on `deploy-pages` serializes; full-rebuild idempotency means a coalesced run still produces correct output.
- **First commit on a branch.** `HEAD~1` doesn't exist; the bump step guards and skips.
- **Manual hotfix minor collision.** Two maintainers could pick the same next-minor for the same env+major. Mitigation: documented "always re-fetch tags before tagging" + tag protection prevents move/overwrite (collision fails the push).
- **Editor write surface.** The `audiflow-preset-editor` writes to `presets/` on whichever branch is checked out. With this model that is `main` or `develop` -- a behavior change for the editor's UX (prior model: `dev/vN`). Editor docs must be updated to reflect this.

## Open follow-ups (not blocking)

- Optional `scripts/cut-old-major-tag.sh` helper for the manual hotfix path.
- Consider a periodic `deploy-pages` `workflow_dispatch` (cron) as a self-heal safety net.
