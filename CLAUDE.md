# audiflow-smartplaylist

Smart playlist configuration data for all environments. Static JSON files deployed to GitHub Pages via CI. The app fetches configs from `https://audiflow.github.io/audiflow-smartplaylist/`.

## Branch and deployment model

`main` holds infrastructure (workflows, docs, CODEOWNERS). Data lives on env/version branches:

| Branch | Deploy path | URL |
|--------|------------|-----|
| `prod/v1` | `/assets/v1/` | `audiflow.github.io/audiflow-smartplaylist/assets/v1/` |
| `prod/v2` | `/assets/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets/v2/` |
| `stg/v2` | `/assets-stg/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets-stg/v2/` |
| `dev/v2` | `/assets-dev/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets-dev/v2/` |

Branch flow per version: `dev/v{N}` -> PR -> `stg/v{N}` -> PR -> `prod/v{N}`

Multiple schema versions can be served concurrently. Old versions remain deployable for bug fixes.

## Ecosystem context

The single data repo in the audiflow ecosystem (formerly split into prod and dev repos). The `audiflow-smartplaylist-editor` web tool reads/writes these files locally; users commit and push. Schema SSoT lives in `audiflow-smartplaylist-editor/crates/sp_core/assets/`.

## Responsibilities

- Playlist configurations for all environments (JSON under `patterns/`)
- CI deployment to GitHub Pages (via `.github/workflows/deploy-pages.yml`)
- Schema vendoring for local validation (`schema/`)

## Non-responsibilities

- Schema definitions (owned by `audiflow-smartplaylist-editor`)
- Config editing workflow (owned by editor)
- App-side consumption logic (owned by `audiflow`)

## File layout

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
# Local schema validation (requires gh CLI)
schema/scripts/validate.sh patterns/

# CI validates on PR via editor's sp_cli
# See .github/workflows/validate.yml
```

## Key references

- docs/overview.md -- purpose, concepts, entry points
- docs/architecture/system-overview.md -- data flow and design constraints
- docs/specs/file-structure.md -- three-level JSON hierarchy spec
- docs/development/change-workflow.md -- how to add/modify patterns

## When changing this repository

- All JSON must conform to schemas in `schema/`
- Changes to `patterns/` deploy automatically on merge to the target branch
- Schema SSoT is in the editor repo; vendor updated schemas into `schema/`
- Check whether docs/specs/file-structure.md needs updating

## Codex notes

- If the user names a local skill or asks to use a repo-specific skill, check `.agents/skills/<skill-name>/agents/openai.yaml` before assuming the skill is unavailable.
- For playlist-pattern work, also check `.agents/skills/audiflow-playlist/agents/openai.yaml` and the files it references, even if the skill was not surfaced by the runtime's built-in skill list.
- Treat `.agents/skills/**/SKILL.md`, referenced files under `related_paths`, and any symlink targets they point to as part of the repo's working instructions.
