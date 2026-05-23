# Config File Structure

Smart playlist configurations are stored as a three-level file hierarchy in the data repository.

## Directory Layout

```
meta.json                           # Root: version + pattern summaries
{patternId}/
  meta.json                         # Pattern: feed matching + playlist IDs
  playlists/
    {playlistId}.json               # Playlist definition (SmartPlaylistDefinition)
```

## Root meta.json

Lists all available pattern configs with summary information for browsing.

```json
{
  "dataVersion": 1,
  "schemaVersion": 1,
  "patterns": [
    {
      "id": "coten_radio",
      "dataVersion": 1,
      "displayName": "Coten Radio",
      "feedUrlHint": "https://anchor.fm/s/8c2088c/podcast/rss",
      "playlistCount": 3
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `dataVersion` | integer | Data format version (must be 1) |
| `schemaVersion` | integer | Schema definition version |
| `patterns` | array | Pattern summaries for discovery |
| `patterns[].id` | string | Pattern directory name |
| `patterns[].dataVersion` | integer | Pattern data version (incremented on change) |
| `patterns[].displayName` | string | Human-readable name |
| `patterns[].feedUrlHint` | string | Feed URL for identification |
| `patterns[].playlistCount` | integer | Number of playlist definitions |

## Pattern meta.json

Located at `{patternId}/meta.json`. Contains feed matching rules and an ordered list of playlist IDs.

```json
{
  "dataVersion": 1,
  "id": "coten_radio",
  "podcastGuid": "abc-123-def",
  "feedUrls": [
    "https://anchor.fm/s/8c2088c/podcast/rss"
  ],
  "yearGroupedEpisodes": false,
  "playlists": ["seasons", "specials", "by-year"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dataVersion` | integer | yes | Pattern data version |
| `id` | string | yes | Must match directory name |
| `podcastGuid` | string | no | GUID for exact matching (checked first) |
| `feedUrls` | array of strings | yes | Feed URLs for matching |
| `yearGroupedEpisodes` | boolean | no | Group all-episodes view by year (default: false) |
| `playlists` | array of strings | yes | Ordered playlist IDs, each maps to `playlists/{id}.json` |

## Playlist definition

Located at `{patternId}/playlists/{playlistId}.json`. Contains a single playlist definition as defined in [playlist-definition.schema.json](../playlist-definition.schema.json).

See the [examples](../examples/) directory for complete playlist definitions using each resolver type.

## Loading Strategy

Consumers load configs lazily by level:

1. Fetch `meta.json` to discover available patterns
2. Fetch `{patternId}/meta.json` for feed matching and playlist list
3. Fetch individual `playlists/{id}.json` as needed

This allows efficient caching at each level -- root metadata changes rarely, while individual playlists may be updated independently.
