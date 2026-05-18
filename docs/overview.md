# Overview

## Purpose

audiflow-preset is the configuration data repository for the audiflow podcast ecosystem's preset feature. It stores JSON config files that define how podcast episodes are grouped, filtered, sorted, and displayed within the audiflow mobile app. These files are deployed as static assets to GitHub Pages and fetched by the app at runtime.

## Responsibilities

- Store preset configuration JSON files for all environments (prod, staging, dev)
- Host vendored JSON Schema files for local validation (on env/version branches)
- Provide CI pipelines for validation (on PR) and deployment (on merge to target branch)
- Auto-bump `dataVersion` fields via CI when presets change

## Non-responsibilities

- Schema authoring or evolution (owned by `audiflow-preset-editor`)
- Config editing UX (owned by `audiflow-preset-editor`)
- App-side parsing, caching, or playback logic (owned by `audiflow`)

## Main concepts

- **Preset**: A podcast-specific configuration bundle. Each preset maps to one podcast via feed URL or GUID matching. Directory: `presets/{presetId}/`.
- **Playlist definition**: A single JSON file describing how to group and display episodes for one playlist within a preset. Located at `presets/{presetId}/playlists/{playlistId}.json`.
- **Resolver type**: The algorithm a playlist uses to group episodes. Valid values: `rss`, `category`, `year`, `titleAppearanceOrder`.
- **Root index** (`presets/meta.json`): Discovery file listing all presets with summary info. The app fetches this first.
- **PresetMeta** (`{presetId}/meta.json`): Per-preset file with feed matching rules and ordered playlist IDs.
- **dataVersion**: Monotonically increasing integer bumped by CI when data changes. Used by the app for cache invalidation.
- **schemaVersion**: Integer indicating structural schema version. Bumped only when JSON structure changes (not data-only changes).
- **Env/version branch**: Data and schemas live on branches like `prod/v7`, `stg/v7`, `dev/v7` -- not on `main`.

## Primary entry points

On env/version branches (e.g., `prod/v7`):
- `presets/meta.json`: Root index, start here to understand available presets
- `presets/{presetId}/meta.json`: Per-preset metadata (feed matching, playlist list)
- `presets/{presetId}/playlists/{playlistId}.json`: Individual playlist definitions
- `schema/playlist-definition.schema.json`: Primary schema for playlist definitions
- `schema/scripts/validate.sh`: Local validation script

On `main`:
- `.github/workflows/`: CI pipelines for validation and deployment
- `docs/`: Repository documentation
- `scripts/`: Infrastructure scripts

## Key dependencies

- `audiflow-preset-editor` (`audiflow-editor` binary): CI uses pre-compiled binary for validation and version bumping
- GitHub Pages: Static hosting for all environments
- GitHub Actions: CI/CD

## Read next

- docs/architecture/system-overview.md
- docs/architecture/multi-env-deploy.md
- docs/specs/file-structure.md
- docs/development/change-workflow.md

## When to update

Update this document when:
- Repository purpose or scope changes
- New preset types or resolver types are added
- Responsibility boundaries shift between ecosystem repos
- New external dependencies are introduced
