# File Structure Specification

> **Naming migration in progress.** The "smartplaylist" naming is being
> retired in favor of "preset" (see `docs/architecture/naming-migration.md`).
> Data and code on `v7+` branches use the new vocabulary; `v6` branches
> retain the legacy names until deprecation.

## Purpose

Defines the three-level JSON file hierarchy used by this repository to store smart playlist configurations. All consumers (app, editor, CI tools) depend on this structure.

Note: This file structure exists on env/version branches (e.g., `prod/v2`, `dev/v2`), not on `main`. The `main` branch holds infrastructure only (workflows, docs, scripts).

## Definitions

- **Root index**: `patterns/meta.json` -- discovery file listing all available patterns
- **Pattern meta**: `patterns/{patternId}/meta.json` -- per-podcast feed matching and playlist list
- **Playlist definition**: `patterns/{patternId}/playlists/{playlistId}.json` -- episode grouping/filtering/sorting rules
- **patternId**: Directory name identifying a podcast pattern (e.g., `coten_radio`, `business-wars`)
- **playlistId**: Filename (without `.json`) of a playlist definition; must match the `id` field inside the file

## Scope

This document defines:
- The directory layout and naming conventions
- The role and required fields of each file type
- The relationship between the three levels
- The loading strategy for consumers

This document does not define:
- Full schema field descriptions (see `schema/*.schema.json` on env branches)
- Resolver algorithm behavior (see schema descriptions in `schema/playlist-definition.schema.json`)
- Editor workflow for creating configs (see editor repo docs)

## Directory layout

On each env/version branch (e.g., `prod/v2`):

```
patterns/
  meta.json                              # Root index (schema: pattern-index.schema.json)
  {patternId}/
    meta.json                            # Pattern meta (schema: pattern-meta.schema.json)
    playlists/
      {playlistId}.json                  # Playlist def (schema: playlist-definition.schema.json)
schema/
  pattern-index.schema.json              # Schema for root index
  pattern-meta.schema.json               # Schema for pattern meta
  playlist-definition.schema.json        # Schema for playlist definitions
  scripts/validate.sh                    # Local validation script
  examples/                              # Reference examples per resolver type
  docs/                                  # Generated schema documentation
```

## Root index (`patterns/meta.json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dataVersion` | integer | yes | Monotonically increasing; bumped by CI on any pattern change |
| `schemaVersion` | integer | yes | Structural version; bumped on breaking format changes |
| `patterns` | array | yes | Summary entries for all patterns |

Each entry in `patterns`:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Must match the pattern directory name |
| `dataVersion` | integer | yes | Mirrors value in `{id}/meta.json` |
| `displayName` | string | yes | Human-readable podcast name |
| `feedUrlHint` | string | yes | Substring of feed URL for fast pre-filtering |
| `playlistCount` | integer | yes | Number of playlist definitions |

## Pattern meta (`{patternId}/meta.json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dataVersion` | integer | yes | Bumped by CI when any file in this pattern changes |
| `id` | string | yes | Must match parent directory name |
| `podcastGuid` | string | no | GUID for exact matching (checked before feedUrls) |
| `feedUrls` | string[] | yes | Exact feed URLs for matching (min 1) |
| `yearGroupedEpisodes` | boolean | no | Show year headers in all-episodes view (default: false) |
| `playlists` | string[] | yes | Ordered playlist IDs; each maps to `playlists/{id}.json` (min 1) |

## Playlist definition (`{patternId}/playlists/{playlistId}.json`)

Required fields: `id`, `displayName`, `resolverType`.

Valid `resolverType` values:

| Resolver | Grouping strategy | Key fields |
|----------|-------------------|------------|
| `rss` | By iTunes season number from RSS metadata | `nullSeasonGroupKey`, `titleExtractor`, `smartPlaylistEpisodeExtractor` |
| `category` | By title regex patterns in `groups` array | `groups` (required) |
| `year` | By publication year | `titleExtractor`, `smartPlaylistEpisodeExtractor` |
| `titleAppearanceOrder` | By recurring title pattern, ordered by first appearance | `titleExtractor`, `groups[0].pattern` (fallback) |

See `schema/playlist-definition.schema.json` for complete field definitions.

## Loading strategy

Consumers load configs lazily by level:

1. Fetch `meta.json` -- discover available patterns, use `feedUrlHint` for pre-filtering
2. Fetch `{patternId}/meta.json` -- exact feed matching via `podcastGuid` or `feedUrls`
3. Fetch `playlists/{id}.json` -- load individual definitions as needed

Each level is independently cacheable. The `dataVersion` fields enable cache invalidation without re-fetching unchanged data.

## Consistency rules

- `patternId` directory name must match `id` field in that pattern's `meta.json`
- `playlistId` filename (minus `.json`) must match `id` field inside the playlist definition
- Root index `patterns[].id` must match an existing `{patternId}/` directory
- Root index `patterns[].dataVersion` must match `{patternId}/meta.json` `dataVersion`
- Root index `patterns[].playlistCount` must equal the length of `{patternId}/meta.json` `playlists` array
- Pattern meta `playlists` array entries must each have a corresponding `playlists/{id}.json` file

## Invalid cases

- Missing required fields in any JSON file
- `id` mismatch between filename/directory and field value
- `resolverType` value not in `[rss, category, year, titleAppearanceOrder]`
- `category` resolver without a `groups` array
- `dataVersion` or `playlistCount` mismatch between root index and pattern meta
- Additional properties not defined in the schema (all schemas use `additionalProperties: false`)

## Compatibility notes

- Adding new optional fields to playlist definitions is backward-compatible (app ignores unknown fields if schema allows)
- Adding new resolver types requires app update (unknown resolver types are not handled)
- Changing `schemaVersion` signals a potentially breaking structural change
- `dataVersion` changes are always backward-compatible (data-only)

## When to update

Update this document when:
- New file types are added to the hierarchy
- Required fields change in any of the three schemas
- New resolver types are introduced
- Loading strategy or caching behavior changes
- Consistency rules are added or modified
