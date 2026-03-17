# Change Workflow

## Before making changes

- Read docs/overview.md for repository context
- Read docs/specs/file-structure.md for the JSON hierarchy specification
- Read docs/architecture/multi-env-deploy.md for the branch model
- Identify whether the change affects:
  - An existing pattern (modify files on the appropriate env/version branch)
  - A new pattern (create new directory on a dev branch)
  - Schema or validation (coordinate with `audiflow-smartplaylist-editor` first)
- Data changes go on env/version branches (e.g., `dev/v2`), not `main`

## Adding a new pattern

1. Check out the appropriate dev branch (e.g., `dev/v2`)
2. Create directory: `patterns/{patternId}/`
3. Create `patterns/{patternId}/meta.json` with required fields (`dataVersion`, `id`, `feedUrls`, `playlists`)
4. Create `patterns/{patternId}/playlists/{playlistId}.json` for each playlist
5. Add an entry to `patterns/meta.json` `patterns` array with matching `id`, `dataVersion`, `displayName`, `feedUrlHint`, `playlistCount`
6. Validate locally: `schema/scripts/validate.sh patterns/**/*.json`
7. Open PR to the dev branch -- CI runs `audiflow-editor validate`

## Modifying an existing pattern

1. Check out the appropriate env/version branch
2. Edit the relevant JSON files under `patterns/{patternId}/`
3. Do NOT manually bump `dataVersion` -- CI handles this on merge
4. Validate locally: `schema/scripts/validate.sh patterns/{patternId}/**/*.json`
5. Open PR -- CI validates

## Adding a playlist to an existing pattern

1. Create `patterns/{patternId}/playlists/{newPlaylistId}.json`
2. Add `{newPlaylistId}` to the `playlists` array in `patterns/{patternId}/meta.json`
3. Update `playlistCount` in the root `patterns/meta.json` entry for this pattern
4. Validate locally

## Promoting data across environments

Branch flow per version: `dev/v{N}` -> PR -> `stg/v{N}` -> PR -> `prod/v{N}`

Each merge triggers CI deployment to the corresponding GitHub Pages path.

## Schema changes

Schema changes originate in `audiflow-smartplaylist-editor`, not here. If a schema change is needed:
1. Update schema in `audiflow-smartplaylist-editor/crates/sp_core/assets/`
2. Update editor models and tests
3. Copy updated schema files to this repo's `schema/` directory (on the relevant env/version branch)
4. Update affected configs in `patterns/` to conform
5. Update `docs/specs/file-structure.md` if structure changed
6. Run conformance tests in `audiflow` app repo

## During implementation

- Keep changes localized to one pattern when possible
- Ensure `id` fields match directory/file names exactly
- Use existing patterns as reference (e.g., `coten_radio` for `rss` resolver)
- All JSON must use `additionalProperties: false` per schema -- no extra fields

## Validation checklist

- [ ] Local validation passes: `schema/scripts/validate.sh patterns/**/*.json`
- [ ] `id` fields match directory and file names
- [ ] Root index `playlistCount` matches actual playlist count
- [ ] Root index entry `dataVersion` matches pattern meta `dataVersion`
- [ ] Relevant docs updated (if structure or process changed)

## CI behavior

- **On PR to env/version branch** (`validate.yml`): Downloads pre-compiled `audiflow-editor` binary, runs `validate` against `patterns/`
- **On merge to env/version branch** (`deploy-pages.yml`):
  1. Runs `audiflow-editor bump-versions` to increment `dataVersion` in affected files
  2. Commits the version bump to the source branch
  3. Deploys `patterns/` to the appropriate GitHub Pages directory

## When to update

Update this document when:
- CI pipeline steps change
- New validation requirements are added
- The relationship with editor repo tooling changes
- New pattern or file types are introduced
- Branch model or promotion flow changes
