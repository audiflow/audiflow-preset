# File Structure Specification

## Purpose

Defines the three-level JSON file hierarchy used by this repository to store preset configurations. All consumers (app, editor, CI tools) depend on this structure.

Note: This file structure exists on env/version branches (e.g., `prod/v7`, `dev/v7`), not on `main`. The `main` branch holds infrastructure only (workflows, docs, scripts).

## Definitions

- **Root index**: `presets/meta.json` -- discovery file listing all available presets
- **PresetMeta**: `presets/{presetId}/meta.json` -- per-podcast feed matching and playlist list
- **Playlist definition**: `presets/{presetId}/playlists/{playlistId}.json` -- episode grouping/filtering/sorting rules
- **presetId**: Directory name identifying a podcast preset (e.g., `coten_radio`, `business-wars`)
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

On each env/version branch (e.g., `prod/v7`):

```
presets/
  meta.json                              # Root index (schema: preset-index.schema.json)
  {presetId}/
    meta.json                            # PresetMeta (schema: preset-meta.schema.json)
    playlists/
      {playlistId}.json                  # Playlist def (schema: playlist-definition.schema.json)
schema/
  preset-index.schema.json               # Schema for root index
  preset-meta.schema.json                # Schema for preset meta
  playlist-definition.schema.json        # Schema for playlist definitions
  scripts/validate.sh                    # Local validation script
  examples/                              # Reference examples per resolver type
  docs/                                  # Generated schema documentation
```

## Root index (`presets/meta.json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dataVersion` | integer | yes | Monotonically increasing; bumped by CI on any preset change |
| `schemaVersion` | integer | yes | Structural version; bumped on breaking format changes |
| `presets` | array | yes | PresetSummary entries for all presets |

Each entry in `presets` (PresetSummary):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Must match the preset directory name |
| `dataVersion` | integer | yes | Mirrors value in `{id}/meta.json` |
| `displayName` | string | yes | Human-readable podcast name |
| `feedUrlHint` | string | yes | Substring of feed URL for fast pre-filtering |
| `playlistCount` | integer | yes | Number of playlist definitions |

## PresetMeta (`{presetId}/meta.json`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dataVersion` | integer | yes | Bumped by CI when any file in this preset changes |
| `id` | string | yes | Must match parent directory name |
| `podcastGuid` | string | no | GUID for exact matching (checked before feedUrls) |
| `feedUrls` | string[] | yes | Exact feed URLs for matching (min 1) |
| `yearGroupedEpisodes` | boolean | no | Show year headers in all-episodes view (default: false) |
| `playlists` | string[] | yes | Ordered playlist IDs; each maps to `playlists/{id}.json` (min 1) |

## Playlist definition (`{presetId}/playlists/{playlistId}.json`)

Required fields: `id`, `displayName`, `resolverType`.

Valid `resolverType` values:

| Resolver | Grouping strategy | Key fields |
|----------|-------------------|------------|
| `rss` | By iTunes season number from RSS metadata | `nullSeasonGroupKey`, `titleExtractor`, `presetEpisodeExtractor` |
| `category` | By title regex patterns in `groups` array | `groups` (required) |
| `year` | By publication year | `titleExtractor`, `presetEpisodeExtractor` |
| `titleAppearanceOrder` | By recurring title pattern, ordered by first appearance | `titleExtractor`, `groups[0].pattern` (fallback) |

See `schema/playlist-definition.schema.json` for complete field definitions.

## Loading strategy

Consumers load configs lazily by level:

1. Fetch `meta.json` -- discover available presets, use `feedUrlHint` for pre-filtering
2. Fetch `{presetId}/meta.json` -- exact feed matching via `podcastGuid` or `feedUrls`
3. Fetch `playlists/{id}.json` -- load individual definitions as needed

Each level is independently cacheable. The `dataVersion` fields enable cache invalidation without re-fetching unchanged data.

## Consistency rules

- `presetId` directory name must match `id` field in that preset's `meta.json`
- `playlistId` filename (minus `.json`) must match `id` field inside the playlist definition
- Root index `presets[].id` must match an existing `{presetId}/` directory
- Root index `presets[].dataVersion` must match `{presetId}/meta.json` `dataVersion`
- Root index `presets[].playlistCount` must equal the length of `{presetId}/meta.json` `playlists` array
- PresetMeta `playlists` array entries must each have a corresponding `playlists/{id}.json` file

## Invalid cases

- Missing required fields in any JSON file
- `id` mismatch between filename/directory and field value
- `resolverType` value not in `[rss, category, year, titleAppearanceOrder]`
- `category` resolver without a `groups` array
- `dataVersion` or `playlistCount` mismatch between root index and preset meta
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
