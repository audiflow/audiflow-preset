# Multi-environment deployment

This repo serves prod and dev environments across multiple schema majors from a single GitHub Pages deployment. Each deploy is driven by a git tag; old majors stay published as long as their tags exist.

## Source model

One long-lived branch, `main`: `prod/v{M}.{m}` tags are cut here automatically. The former `develop` branch, which cut `dev/v{M}.{m}` tags, was retired; `dev/v7.10` is the last dev tag, so `assets-dev/v7/` is frozen and no `assets-dev/v8/` exists unless a `dev/v8.*` tag is pushed manually.

`presets/` and `schema/` live at the repo root. There is no per-env or per-version source directory.

## Tag convention

`{env}/v{schemaVersion}.{dataVersion}` where `env in {prod, dev}`.

- `schemaVersion` is read from `presets/meta.json` (sole SoT for schema major).
- `dataVersion` is read from `presets/meta.json`, bumped automatically by CI on every push.
- Same commit may carry multiple env tags (e.g. `prod/v7.10` and `dev/v7.10`) when promotion produces identical content.

## Deploy artifact layout

Each deploy uploads a Pages artifact with this tree (no persistent deploy branch):

```
_site/
  assets/v7/       <- highest-minor prod/v7.* tag
  assets/v8/       <- highest-minor prod/v8.* tag
  assets-dev/v7/   <- highest-minor dev/v7.* tag
  assets-dev/v8/   <- highest-minor dev/v8.* tag
```

## How it works

- Push to `main` (touching `presets/**.json`) -> `bump-versions.yml` runs `audiflow-editor bump-versions`, commits, and tags `{env}/v{schemaVersion}.{dataVersion}`.
- That tag push -> `deploy-pages.yml` enumerates all matching tags, picks the highest minor per `(env, major)`, builds the deploy tree from the winning tags' `presets/` content into `_site/`, uploads it via `actions/upload-pages-artifact`, and publishes it via `actions/deploy-pages`. Each deploy fully replaces the live tree; directories without a backing tag (e.g. legacy `assets-stg/*`) simply do not appear in the new artifact.

## Schema major lifecycle

1. Schema v7 is current: `presets/meta.json:.schemaVersion = 7`.
2. Schema v8 ships: once the editor `v8` release exists, bump `schemaVersion` to 8 on `feat/v8`, migrate all presets, and merge the PR into `main` (see docs/development/version-branch-rollout.md).
3. Bug fix for v7: check out an old `prod/v7.x` tag, branch off, fix, manually tag `prod/v7.{x+1}`, push the tag.
4. Both `/assets/v7/` and `/assets/v8/` are served concurrently.
5. Sunset v7: delete every `prod/v7.*` and `dev/v7.*` tag; next deploy run drops the directory.

## Branch + tag protection

- `main`: PR required, `validate` must pass, no force-push, no delete.
- Tags `prod/**`, `dev/**`: protected ruleset; only maintainers and `audiflow-ci-bot[bot]` can create; no delete, no overwrite.

## GitHub Pages configuration

Pages source is set to "GitHub Actions" (Settings > Pages > Build and deployment > Source). No persistent deploy branch exists; each successful `deploy-pages.yml` run publishes a fresh artifact via `actions/deploy-pages`.
