# audiflow-smartplaylist

Smart playlist configuration data for all environments. Static JSON files deployed to GitHub Pages via CI. The app fetches configs from `https://audiflow.github.io/audiflow-smartplaylist/`.

## Branch and deployment model

`main` holds infrastructure (workflows, docs, scripts). Data and vendored schemas live on env/version branches:

| Branch | Deploy path | URL |
|--------|------------|-----|
| `prod/v1` | `/assets/v1/` | `audiflow.github.io/audiflow-smartplaylist/assets/v1/` |
| `prod/v2` | `/assets/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets/v2/` |
| `stg/v2` | `/assets-stg/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets-stg/v2/` |
| `dev/v2` | `/assets-dev/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets-dev/v2/` |

Branch flow per version: `dev/v{N}` -> PR -> `stg/v{N}` -> PR -> `prod/v{N}`

Multiple schema versions can be served concurrently. Old versions remain deployable for bug fixes.

## Ecosystem context

The single data repo in the audiflow ecosystem (3 repos: app, editor, config data). The `audiflow-smartplaylist-editor` web tool reads/writes these files locally; users commit and push. Schema SSoT lives in `audiflow-smartplaylist-editor/crates/sp_core/assets/`.

## Responsibilities

- Playlist configurations for all environments (JSON under `patterns/` on env branches)
- CI deployment to GitHub Pages (via `.github/workflows/deploy-pages.yml`)
- Schema vendoring for local validation (`schema/` on env branches)

## Non-responsibilities

- Schema definitions (owned by `audiflow-smartplaylist-editor`)
- Config editing workflow (owned by editor)
- App-side consumption logic (owned by `audiflow`)

## File layout

On `main` (infrastructure only):
```
.github/workflows/    # CI pipelines
docs/                 # Repository documentation
scripts/              # Infrastructure scripts
```

On env/version branches (e.g., `prod/v2`):
```
patterns/
  meta.json                    # Root index: dataVersion, schemaVersion, pattern summaries
  {patternId}/
    meta.json                  # Pattern: feedUrls, playlists list, flags
    playlists/
      {playlistId}.json        # PlaylistDefinition (one per playlist)
schema/                        # Vendored schemas + validation tooling
```

## Validation

```bash
# Local schema validation (on env branches, requires uv)
schema/scripts/validate.sh patterns/**/*.json

# CI validates on PR via editor's pre-compiled audiflow-editor binary
# See .github/workflows/validate.yml
```

## Key references

- docs/overview.md -- purpose, concepts, entry points
- docs/architecture/system-overview.md -- data flow and design constraints
- docs/architecture/multi-env-deploy.md -- branch model and deployment
- docs/specs/file-structure.md -- three-level JSON hierarchy spec
- docs/development/change-workflow.md -- how to add/modify patterns

## When changing this repository

- Data changes go on env/version branches (e.g., `dev/v2`), not `main`
- All JSON must conform to schemas in `schema/` (on the same branch)
- Changes to `patterns/` deploy automatically on merge to the target branch
- Schema SSoT is in the editor repo; vendor updated schemas into `schema/`
- Check whether docs/specs/file-structure.md needs updating
