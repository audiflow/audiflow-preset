# audiflow-preset

Preset configuration data for all environments. Static JSON files deployed to GitHub Pages via CI. The app fetches configs from `https://audiflow.github.io/audiflow-preset/`.

## Branch and deployment model

Single long-lived branch: `main`. PRs target `main` directly (the former `develop` branch was retired; `origin/develop` no longer exists). Each push to `main` is auto-tagged `prod/v{schemaVersion}.{dataVersion}`.

`presets/` and `schema/` live at the repo root.

Deployment is driven by tags. `deploy-pages.yml` builds an artifact from the winning tag's contents and deploys it via GitHub Actions; Pages source is set to "GitHub Actions", no persistent deploy branch. Per major version, the highest-minor `prod/v{major}.*` tag wins:

| Tag | Deploy path | URL |
|-----|-------------|-----|
| `prod/v7.*` (max minor) | `/assets/v7/` | `audiflow.github.io/audiflow-preset/assets/v7/` |
| `prod/v8.*` (max minor) | `/assets/v8/` | ... |

Old-major hotfix: check out an old tag, branch, fix, tag the next free minor manually.

## Ecosystem context

The single data repo in the audiflow ecosystem (3 repos: app, editor, config data). The `audiflow-preset-editor` web tool reads/writes these files locally; users commit and push. Schema SSoT lives in `audiflow-preset-editor/crates/preset_core/assets/`.

## Responsibilities

- Preset configurations for all environments (JSON under `presets/` on env branches)
- CI deployment to GitHub Pages (via `.github/workflows/deploy-pages.yml`)
- Schema vendoring for local validation (`schema/` on env branches)

## Non-responsibilities

- Schema definitions (owned by `audiflow-preset-editor`)
- Config editing workflow (owned by editor)
- App-side consumption logic (owned by `audiflow`)

## File layout

```
.github/workflows/    # CI: validate, bump-versions, deploy-pages
docs/                 # Repository documentation
scripts/              # CI helpers (scripts/ci/*) + repo tooling
presets/
  meta.json                    # Root index: schemaVersion, dataVersion, preset summaries
  {presetId}/
    meta.json                  # PresetMeta: feedUrls, playlists list, flags
    playlists/
      {playlistId}.json        # PlaylistDefinition (one per playlist)
schema/                        # Vendored schemas + validation tooling
tests/scripts/                 # Bash test harness for scripts/ci/
```

## Validation

```bash
# Local schema validation (on env branches, requires uv)
schema/scripts/validate.sh presets/**/*.json

# CI validates on PR via editor's pre-compiled audiflow-editor binary
# See .github/workflows/validate.yml
```

## Key references

- docs/overview.md -- purpose, concepts, entry points
- docs/architecture/system-overview.md -- data flow and design constraints
- docs/architecture/multi-env-deploy.md -- branch model and deployment
- docs/specs/file-structure.md -- three-level JSON hierarchy spec
- docs/development/change-workflow.md -- how to add/modify presets

## When changing this repository

- Data changes go through a PR into `main`
- All JSON must conform to schemas in `schema/`
- Changes to `presets/` deploy automatically on merge to `main` (auto-tag + `deploy-pages.yml`)
- Schema SSoT is in the editor repo; vendor updated schemas into `schema/`
- Check whether docs/specs/file-structure.md needs updating
