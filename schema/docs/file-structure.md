# Config File Structure

Preset configurations are stored as a three-level file hierarchy in the data repository.

## Directory Layout

```
meta.json                           # Root: version + preset summaries
{presetId}/
  meta.json                         # Preset: feed matching + playlist IDs
  playlists/
    {playlistId}.json               # Playlist definition (PlaylistDefinition)
```

## Root meta.json

Lists all available presets with summary information for browsing.

```json
{
  "dataVersion": 2,
  "schemaVersion": 7,
  "presets": [
    {
      "dataVersion": 2,
      "displayName": "Coten Radio",
      "feedUrlHint": "https://anchor.fm/s/8c2088c/podcast/rss",
      "id": "2e86c4b573b7",
      "playlistCount": 3
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `dataVersion` | integer | Data format version (monotonically increasing, bumped when any preset changes) |
| `schemaVersion` | integer | Schema definition version |
| `presets` | array | Preset summaries for discovery |
| `presets[].id` | string | Preset directory name |
| `presets[].dataVersion` | integer | Preset data version (incremented on change) |
| `presets[].displayName` | string | Human-readable name |
| `presets[].feedUrlHint` | string | Feed URL for identification |
| `presets[].playlistCount` | integer | Number of playlist definitions |

## Preset meta.json

Located at `{presetId}/meta.json`. Contains feed matching rules and an ordered list of playlist IDs.

```json
{
  "dataVersion": 2,
  "feedUrls": [
    "https://anchor.fm/s/8c2088c/podcast/rss"
  ],
  "id": "2e86c4b573b7",
  "playlists": ["regular", "short", "extras"],
  "showEpisodeThumbnail": true,
  "yearGroupedEpisodes": true
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dataVersion` | integer | yes | Preset data version |
| `id` | string | yes | Must match directory name |
| `podcastGuid` | string | no | GUID for exact matching (checked first) |
| `feedUrls` | array of strings | yes | Feed URLs for matching |
| `yearGroupedEpisodes` | boolean | no | Group all-episodes view by year (default: false) |
| `showEpisodeThumbnail` | boolean | no | Show episode thumbnail in main episode list (default: true) |
| `playlists` | array of strings | yes | Ordered playlist IDs, each maps to `playlists/{id}.json` |

## Playlist definition

Located at `{presetId}/playlists/{playlistId}.json`. Contains a single playlist definition as defined in [playlist-definition.schema.json](../playlist-definition.schema.json).

See the [examples](../examples/) directory for complete playlist definitions using each resolver type.

## Loading Strategy

Consumers load configs lazily by level:

1. Fetch `meta.json` to discover available presets
2. Fetch `{presetId}/meta.json` for feed matching and playlist list
3. Fetch individual `playlists/{id}.json` as needed

This allows efficient caching at each level -- root metadata changes rarely, while individual playlists may be updated independently.
