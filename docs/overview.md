# Overview

## Purpose

audiflow-smartplaylist is the production configuration data repository for the audiflow podcast ecosystem's smart playlist feature. It stores JSON config files that define how podcast episodes are grouped, filtered, sorted, and displayed within the audiflow mobile app. These files are deployed as static assets to GitHub Pages and fetched by the app at runtime.

## Responsibilities

- Store production-ready playlist configuration JSON files
- Host vendored JSON Schema files for local validation
- Provide CI pipelines for validation (on PR) and deployment (on merge to main)
- Auto-bump `dataVersion` fields via CI when patterns change

## Non-responsibilities

- Schema authoring or evolution (owned by `audiflow-smartplaylist-dev`)
- Config editing UX (owned by `audiflow-smartplaylist-editor`)
- Dev/staging experimentation data (owned by `audiflow-smartplaylist-dev`)
- App-side parsing, caching, or playback logic (owned by `audiflow`)

## Main concepts

- **Pattern**: A podcast-specific configuration bundle. Each pattern maps to one podcast via feed URL or GUID matching. Directory: `patterns/{patternId}/`.
- **Playlist definition**: A single JSON file describing how to group and display episodes for one playlist within a pattern. Located at `patterns/{patternId}/playlists/{playlistId}.json`.
- **Resolver type**: The algorithm a playlist uses to group episodes. Valid values: `seasonNumber`, `year`, `titleDiscovery`, `titleClassifier`.
- **Root index** (`patterns/meta.json`): Discovery file listing all patterns with summary info. The app fetches this first.
- **Pattern meta** (`{patternId}/meta.json`): Per-pattern file with feed matching rules and ordered playlist IDs.
- **dataVersion**: Monotonically increasing integer bumped by CI when data changes. Used by the app for cache invalidation.
- **schemaVersion**: Integer indicating structural schema version. Bumped only when JSON structure changes (not data-only changes).

## Primary entry points

- `patterns/meta.json`: Root index, start here to understand available patterns
- `patterns/{patternId}/meta.json`: Per-pattern metadata (feed matching, playlist list)
- `patterns/{patternId}/playlists/{playlistId}.json`: Individual playlist definitions
- `schema/playlist-definition.schema.json`: Primary schema for playlist definitions
- `schema/scripts/validate.sh`: Local validation script

## Key dependencies

- `audiflow-smartplaylist-editor` (sp_cli package): CI uses `validate.dart` and `bump_versions.dart`
- `audiflow-editor` binary (downloaded via `gh` CLI): Local schema validation
- GitHub Pages: Static hosting for production deployment

## Read next

- docs/architecture/system-overview.md
- docs/specs/file-structure.md
- docs/development/change-workflow.md

## When to update

Update this document when:
- Repository purpose or scope changes
- New pattern types or resolver types are added
- Responsibility boundaries shift between ecosystem repos
- New external dependencies are introduced
