# System Overview

## Goal

Serve as the source of truth for smart playlist configurations consumed by the audiflow mobile app across all environments (prod, staging, dev). This repository is a static data store with CI-driven validation and deployment -- it contains no application logic.

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

Env/version branches (e.g., `prod/v2`, `stg/v2`, `dev/v2`) hold:
- `patterns/`: All configuration data
  - `meta.json`: Root index for pattern discovery
  - `{patternId}/meta.json`: Per-pattern feed matching and playlist ordering
  - `{patternId}/playlists/{playlistId}.json`: Individual playlist definitions
- `schema/`: Vendored JSON Schema files and validation tooling
  - `playlist-definition.schema.json`: Playlist definition schema
  - `pattern-index.schema.json`: Root index schema
  - `pattern-meta.schema.json`: Pattern meta schema
  - `scripts/validate.sh`: Local validation using check-jsonschema

## Main data flow

1. User edits configs in `audiflow-smartplaylist-editor` (local-first)
2. User commits and pushes changes to an env/version branch in this repository
3. On PR: CI downloads pre-compiled `audiflow-editor` binary, runs `validate` against `patterns/`
4. On merge: CI runs `audiflow-editor bump-versions` to auto-increment `dataVersion` fields
5. CI deploys `patterns/` directory to the appropriate GitHub Pages path (e.g., `/assets/v2/`)
6. App fetches `meta.json` -> pattern meta -> playlist definitions (lazy, cached)

## Primary interfaces

- **Input**: JSON files authored by the editor tool, committed via git to env/version branches
- **Output**: Static files served at `https://audiflow.github.io/audiflow-smartplaylist/`
- **External dependencies**:
  - `audiflow-smartplaylist-editor` (pre-compiled `audiflow-editor` binary): validation and version bumping
  - GitHub Pages: static hosting
  - GitHub Actions: CI/CD

## Design constraints

- No application code in this repository -- data, schema, and infrastructure only
- All JSON must pass schema validation before merge
- `dataVersion` fields are managed by CI, not manually edited
- The `patterns/` directory on each env branch is the deployment root
- Three schemas govern three file types: root index, pattern meta, playlist definition
- Multiple schema versions can be served concurrently (e.g., `/assets/v1/` and `/assets/v2/`)
- `main` branch is infrastructure-only; data lives exclusively on env/version branches

## When to update

Update when: new CI workflows are added, deployment target changes, new schema files are vendored, branch model changes, or the relationship with the editor repo changes.
