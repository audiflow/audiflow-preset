# Change Workflow

## Before making changes

- Read docs/overview.md for repository context
- Read docs/specs/file-structure.md for the JSON hierarchy specification
- Identify whether the change affects:
  - An existing pattern (modify files in `patterns/{patternId}/`)
  - A new pattern (create new directory under `patterns/`)
  - Schema or validation (coordinate with `audiflow-smartplaylist-dev` first)

## Adding a new pattern

1. Create directory: `patterns/{patternId}/`
2. Create `patterns/{patternId}/meta.json` with required fields (`dataVersion`, `id`, `feedUrls`, `playlists`)
3. Create `patterns/{patternId}/playlists/{playlistId}.json` for each playlist
4. Add an entry to `patterns/meta.json` `patterns` array with matching `id`, `dataVersion`, `displayName`, `feedUrlHint`, `playlistCount`
5. Validate locally: `schema/scripts/validate.sh patterns/**/*.json`
6. Open PR -- CI runs `sp_cli validate.dart`

## Modifying an existing pattern

1. Edit the relevant JSON files under `patterns/{patternId}/`
2. Do NOT manually bump `dataVersion` -- CI handles this on merge
3. Validate locally: `schema/scripts/validate.sh patterns/{patternId}/**/*.json`
4. Open PR -- CI validates

## Adding a playlist to an existing pattern

1. Create `patterns/{patternId}/playlists/{newPlaylistId}.json`
2. Add `{newPlaylistId}` to the `playlists` array in `patterns/{patternId}/meta.json`
3. Update `playlistCount` in the root `patterns/meta.json` entry for this pattern
4. Validate locally

## Schema changes

Schema changes originate in `audiflow-smartplaylist-dev`, not here. If a schema change is needed:
1. Update schema in `audiflow-smartplaylist-dev/schema/`
2. Update editor models and tests in `audiflow-smartplaylist-editor`
3. Copy updated schema files to this repo's `schema/` directory
4. Update affected configs in `patterns/` to conform
5. Update `docs/specs/file-structure.md` if structure changed
6. Run conformance tests in `audiflow` app repo

For a new schema **major** version (e.g. v4 -> v5), see
[version-branch-rollout.md](version-branch-rollout.md) for the
`dev/vN` branch creation and CI-gated promotion flow.

## During implementation

- Keep changes localized to one pattern when possible
- Ensure `id` fields match directory/file names exactly
- Use existing patterns as reference (e.g., `patterns/2e86c4b573b7/` for `seasonNumber` resolver)
- All JSON must use `additionalProperties: false` per schema -- no extra fields

## Validation checklist

- [ ] Local validation passes: `schema/scripts/validate.sh patterns/**/*.json`
- [ ] `id` fields match directory and file names
- [ ] Root index `playlistCount` matches actual playlist count
- [ ] Root index entry `dataVersion` matches pattern meta `dataVersion`
- [ ] Relevant docs updated (if structure or process changed)

## CI behavior

- **On PR** (`validate.yml`): Clones editor repo, runs `sp_cli validate.dart` against `patterns/`
- **On merge to main** (`bump-deploy-pages.yml`):
  1. Runs `sp_cli bump_versions.dart` to increment `dataVersion` in affected files
  2. Commits the version bump
  3. Deploys `patterns/` to GitHub Pages

## When to update

Update this document when:
- CI pipeline steps change
- New validation requirements are added
- The relationship with editor repo tooling changes
- New pattern or file types are introduced
