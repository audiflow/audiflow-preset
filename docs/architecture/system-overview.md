# System Overview

## Goal

Serve as the source of truth for preset configurations consumed by the audiflow mobile app across all environments (prod, staging, dev). This repository is a static data store with CI-driven validation and deployment -- it contains no application logic.

## Context

This repository is part of:
- The audiflow podcast ecosystem (3 repos: app, editor, config data)
- A data pipeline: Editor -> Git commit -> CI validation/bump -> GitHub Pages -> App fetch
- A schema contract: all JSON must conform to schemas vendored on env/version branches
- A versioned branch-based deployment model: data lives on `{env}/v{N}` branches, not `main`

## High-level structure

The `main` branch holds infrastructure only:
- `.github/workflows/`: CI pipelines (validation, deployment, version bumping)
- `docs/`: Repository documentation
- `scripts/`: Infrastructure scripts (GitHub rulesets setup)

Env/version branches (e.g., `prod/v7`, `stg/v7`, `dev/v7`) hold:
- `presets/`: All configuration data
  - `meta.json`: Root index for preset discovery
  - `{presetId}/meta.json`: Per-preset feed matching and playlist ordering
  - `{presetId}/playlists/{playlistId}.json`: Individual playlist definitions
- `schema/`: Vendored JSON Schema files and validation tooling
  - `playlist-definition.schema.json`: Playlist definition schema
  - `preset-index.schema.json`: Root index schema
  - `preset-meta.schema.json`: PresetMeta schema
  - `scripts/validate.sh`: Local validation using check-jsonschema

## Main data flow

1. User edits configs in `audiflow-preset-editor` (local-first)
2. User commits and pushes changes to an env/version branch in this repository
3. On PR: CI downloads pre-compiled `audiflow-editor` binary, runs `validate` against `presets/`
4. On merge: CI runs `audiflow-editor bump-versions` to auto-increment `dataVersion` fields
5. CI deploys `presets/` directory to the appropriate GitHub Pages path (e.g., `/assets/v7/`)
6. App fetches `meta.json` -> preset meta -> playlist definitions (lazy, cached)

## Primary interfaces

- **Input**: JSON files authored by the editor tool, committed via git to env/version branches
- **Output**: Static files served at `https://audiflow.github.io/audiflow-preset/`
- **External dependencies**:
  - `audiflow-preset-editor` (pre-compiled `audiflow-editor` binary): validation and version bumping
  - GitHub Pages: static hosting
  - GitHub Actions: CI/CD

## Design constraints

- No application code in this repository -- data, schema, and infrastructure only
- All JSON must pass schema validation before merge
- `dataVersion` fields are managed by CI, not manually edited
- The `presets/` directory on each env branch is the deployment root
- Three schemas govern three file types: root index, preset meta, playlist definition
- Multiple schema versions can be served concurrently (e.g., `/assets/v7/` and `/assets/v8/`)
- `main` branch is infrastructure-only; data lives exclusively on env/version branches

## When to update

Update when: new CI workflows are added, deployment target changes, new schema files are vendored, branch model changes, or the relationship with the editor repo changes.
