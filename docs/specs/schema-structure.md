# Schema Structure

## Purpose

Describes how JSON Schemas are vendored and used within the data repository for validation of preset configurations.

## Scope

This document covers:
- Where vendored schemas live in this repo
- Which schemas exist and what they validate
- How to update vendored schemas from the upstream source

This document does not cover:
- Schema field definitions in detail (see the schema files themselves)
- Schema authorship (owned by `audiflow-preset-editor/crates/preset_core/assets/`)
- App-side schema conformance testing (see audiflow repo docs)

## Schema location

Schemas live on env/version branches (e.g., `prod/v7`, `stg/v7`, `dev/v7`), not on `main`. Each env branch vendors a copy of the schemas for local and CI validation.

```
schema/
  preset-index.schema.json           # Validates presets/meta.json (root index)
  preset-meta.schema.json            # Validates presets/{id}/meta.json (preset meta)
  playlist-definition.schema.json    # Validates presets/{id}/playlists/{id}.json
  scripts/validate.sh                # Local validation script
  examples/                          # Reference examples per resolver type
  docs/                              # Generated schema documentation
```

## Schema files

| Schema file | Validates | Key fields |
|-------------|-----------|------------|
| `preset-index.schema.json` | `presets/meta.json` | `dataVersion`, `schemaVersion`, `presets[]` |
| `preset-meta.schema.json` | `presets/{id}/meta.json` | `id`, `feedUrls`, `playlists[]`, `podcastGuid` |
| `playlist-definition.schema.json` | `playlists/{id}.json` | `id`, `displayName`, `grouping`, resolver-specific fields |

All schemas use `additionalProperties: false`.

## Single source of truth

The canonical schemas are maintained in `audiflow-preset-editor/crates/preset_core/assets/`. This repo vendors copies for offline and CI validation. The editor repo is authoritative; if schemas diverge, the editor version is correct.

## Updating vendored schemas

1. Check out the target env/version branch (e.g., `dev/v7`)
2. Copy updated schema files from `audiflow-preset-editor/crates/preset_core/assets/` into `schema/`
3. Run local validation: `schema/scripts/validate.sh presets/`
4. Fix any data that no longer conforms
5. Commit and push to the env branch

## Validation

```bash
# Local validation (on env branches, requires gh CLI)
schema/scripts/validate.sh presets/

# CI validates automatically on PR via .github/workflows/validate.yml
```

## Related documents

- `docs/specs/file-structure.md` -- three-level JSON hierarchy that schemas validate
- `docs/architecture/system-overview.md` -- data flow and design constraints
- `audiflow-preset-editor` docs -- schema authorship and evolution

## When to update

Update this document when:
- New schema files are added
- Schema vendoring process changes
- Validation tooling or scripts change
- Schema SSoT location changes
