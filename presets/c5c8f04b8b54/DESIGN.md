# ReTACTION Radio

Ryukoku University podcast exploring the intersection of knowledge, business, and Buddhism. Each episode features a professor discussing their research across a multi-episode arc (typically 3-4 episodes per professor). MCs differ by season.

## Feed characteristics

77 episodes across 2 RSS seasons (April 2024 -- April 2026). Title format is consistent:

- Regular: `#{S}-{E} {topic}【{name}{title}編{circled_number}】` (e.g., `#2-65 ...【玉木興慈教授編①】`)
- First episode: `#{S}-{E} {topic}【出演：{name}{title}】` (e.g., `#2-01 ...【出演：入澤崇学長】`)
- Season 1: `#{E} {topic}【...】` (no season prefix in numbering)

Title variants for the bracket suffix:

- `【{name}教授編{n}】` -- professor
- `【{name}准教授編{n}】` -- associate professor
- `【{name}学長編{n}】` -- university president
- `【出演：{name}{title}】` -- first episode of each arc (no `編` suffix)

## Playlist breakdown

Single playlist using two-level grouping:

| Level | What | How |
|-------|------|-----|
| Selector partition | Season 1, Season 2 | `selector.partitionBy: "seasonNumber"` |
| Groups within each season | Professor arcs | `grouping.by: "titleDiscovery"` |

## Episode identification

### Grouping by professor

Uses `titleDiscovery` to auto-detect professor name arcs from bracket patterns. Manual `titleClassifier` was ruled out because there are ~20 professors and new ones appear regularly.

Discovery hint pattern: `【(?:出演：)?(.+?)(?:\s*編.?)?】`

### Title extraction

Group names (professor names) are extracted from titles via `groupItem.titleExtractor`:

- Primary: `【(?:出演：)?(.+?)\s*編` -- captures "玉木興慈教授", "別役重之 准教授"
- Fallback: `【(?:出演：)?(.+?)\s*】` -- for first episodes without `編` suffix

Episode display names strip the number prefix and bracket suffix via `episodeItem.titleExtractor`:

- Pattern: `#\d+(?:-\d+)?\s+(.+?)\s*【` -- extracts the topic text

## Grouping decisions

Selector partitions by season number so each season gets its own dropdown entry with different MCs. Within each season, professor arcs appear as group cards sorted by broadcast order.
