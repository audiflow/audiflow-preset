# Schema major rollout

Operational runbook for landing a new schema major (e.g. v7 -> v8).

## CI contract

- `bump-versions.yml`: triggers on push to `main`/`develop`. Reads `presets/meta.json:.schemaVersion`, downloads `audiflow-editor` from editor release `v{N}`, bumps `dataVersion`, commits, and tags `{env}/v{N}.{dataVersion}`.
- `validate.yml`: triggers on PR to `main`/`develop`. Same `schemaVersion`-keyed download.
- `deploy-pages.yml`: triggers on tag push matching `prod/v*.*` or `dev/v*.*`. Builds the deploy tree from all winning tags and publishes it as a Pages artifact via GitHub Actions (no persistent deploy branch).

## Preconditions

1. `audiflow-preset-editor` has a `vN` Release with the `audiflow-editor-x86_64-unknown-linux-gnu` asset.
2. A feature branch (conventionally `feat/vN`) carries:
   - `presets/meta.json:.schemaVersion` set to N
   - `schema/*.schema.json` vendored from the editor SSoT
   - All `presets/**` migrated to the new schema

## Recommended flow (PR-gated)

1. Open a PR from `feat/vN` into `main` (the former `develop` branch was retired). `validate.yml` runs with the `vN` editor binary.
2. On merge, `bump-versions.yml` cuts `prod/v{N}.{d}` and `deploy-pages.yml` publishes `assets/v{N}/`. `assets/v{N-1}/` keeps being served from its last tag, so released apps are unaffected.
3. Point the app at `assets/v{N}/`, verify, and release it. Fixes to `vN` data go through PRs into `main`; fixes to `v{N-1}` data are old-major hotfixes (see change-workflow.md).

## Anti-patterns

- Don't create a standalone "bump-only" commit for `schemaVersion` or `dataVersion` -- `dataVersion` is bot-managed; `schemaVersion` belongs on `feat/vN`.
- Don't push tags manually for the normal flow -- CI handles it. Manual tags are only for old-major hotfixes (see change-workflow.md).
- Don't create `feat/vN` before the editor `vN` release exists.
