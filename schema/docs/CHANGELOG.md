# Schema Changelog

## Unreleased

### Renamed: `playlistStructure` -> `presentation`

**Values:** `split` -> `separate`, `grouped` -> `combined`

**Why:** The pair `split`/`grouped` lacked a coherent naming axis -- `split` described an action while `grouped` described a state. The new names sit on a clear presentation axis: `separate` means each resolver result is presented as its own playlist (selectable from a dropdown); `combined` means all results are presented as group cards inside a single playlist. The field name `presentation` reflects that this controls how results appear to the user, not internal structure.

### Removed: `priority`

**Why:** The app does not use priority as described in the schema. Episode claiming order is determined by whether a definition has filters (filtered definitions process first, filter-less fallbacks process second), not by a numeric priority value.

## 2026-03-08 -- v2 restructure

### Renamed: `contentType` -> `playlistStructure` (subsequently renamed to `presentation`; see Unreleased)

**Values:** `episodes` -> `split`, `groups` -> `grouped` (subsequently renamed to `separate`/`combined`)

**Format:** Changed from `enum` to `oneOf` with per-value descriptions.

**Why:** `contentType` was too generic. `episodes` described the content, not the structural outcome (one definition splitting into many independent playlists). The new names make the structural choice self-evident: `split` produces many playlists, `grouped` nests groups inside one playlist. (Note: `split` and `grouped` were subsequently renamed to `separate` and `combined`; see Unreleased.)

### Renamed: `yearHeaderMode` -> `groupList.yearBinding`

**Values:** `none` (unchanged), `firstEpisode` -> `pinToYear`, `perEpisode` -> `splitByYear`

**Format:** Changed from `enum` to `oneOf` with per-value descriptions. Moved inside `groupList` object.

**Why:** `yearHeaderMode` described the UI mechanism (headers) rather than the relationship (how groups bind to years). `perEpisode` was misleading -- the behavior is splitting a group across multiple years, parallel to `playlistStructure: split` (subsequently renamed to `presentation: separate`). `firstEpisode` was unclear about what "first" meant; `pinToYear` clearly says the group anchors to one year.

### Renamed: `smartPlaylistEpisodeExtractor` -> `numberingExtractor`

**Why:** Shorter, clearer. The `smartPlaylist` prefix was redundant since the entire schema is about smart playlists.

### Restructured: flat filters -> `episodeFilters` object

**Before:** `titleFilter`, `excludeFilter`, `requireFilter` (three top-level string fields, title-only)
**After:** `episodeFilters: { require?: [EpisodeFilterEntry], exclude?: [EpisodeFilterEntry] }`
where `EpisodeFilterEntry` is `{ title?: string, description?: string }`

**Why:**
- The three original fields were mathematically redundant (`titleFilter` and `requireFilter` are the same operation). Unifying into `require`/`exclude` arrays eliminates this.
- Filtering was hardcoded to episode titles. The new `EpisodeFilterEntry` allows matching against `title`, `description`, or both (AND within an entry).
- Order does not matter (set intersection is commutative): all `require` entries are ANDed, all `exclude` entries are ANDed, and require/exclude are independent.
- Array format supports multiple independent conditions without inventing new field names.

### Restructured: grouped-only display settings -> `groupList` object

**Before:** `yearHeaderMode`, `showSortOrderToggle`, `showDateRange`, `customSort` (flat top-level fields)
**After:** `groupList.yearBinding`, `groupList.userSortable`, `groupList.showDateRange`, `groupList.sort`

**Why:** These settings only apply when `playlistStructure` is `grouped` (subsequently renamed to `presentation: combined`). Nesting them makes the conditional relationship explicit -- the entire `groupList` object is meaningless in `split` (subsequently `separate`) mode.

### Restructured: `episodeYearHeaders` -> `episodeList.showYearHeaders`

**Before:** `episodeYearHeaders` (top-level boolean)
**After:** `episodeList.showYearHeaders`

**Why:** Scoped to the episode list level. The `show` prefix aligns with other boolean display flags (`showDateRange`). Creates a consistent override pattern: definition-level `episodeList` provides defaults, `GroupDef.episodeList` overrides per-group.

### Simplified: `customSort` (SortSpec with rules array) -> `groupList.sort` (single SortRule)

**Before:** `customSort: { rules: [{ field, order, condition }, ...] }` with `SortSpec`, `SortRule`, `SortCondition`
**After:** `groupList.sort: { field, order }`

**Why:** Multi-rule conditional sorting was over-engineered. The use case "most groups ascending, a few descending" is better handled by per-group `GroupDef.episodeList.sort` overrides. Removes `SortSpec` and `SortCondition` from `$defs`.

### Added: cascading override pattern in `GroupDef`

**New fields in GroupDef:**
- `display` object: `showDateRange`, `yearBinding` (overrides groupList defaults)
- `episodeList` object: `showYearHeaders`, `sort`, `titleExtractor` (overrides definition-level episodeList)
- `numberingExtractor` (overrides definition-level numberingExtractor)

**Removed from GroupDef:** `episodeYearHeaders`, `showDateRange` (replaced by nested `display` and `episodeList` objects)

**Why:** The original schema had inconsistent override patterns -- some fields were directly on GroupDef, others weren't overridable at all. The new structure uses the same object shapes at both definition and group levels, making inheritance explicit and consistent.

### Renamed: `showSeasonNumber` -> `prependSeasonNumber`

**Why:** `showSeasonNumber` implied a UI toggle. `prependSeasonNumber` describes the actual behavior: prepending "S{n}" to resolver result names. The verb makes the transformation explicit.

### Renamed: `showSortOrderToggle` -> `groupList.userSortable`

**Default:** `true`

**Why:** `showSortOrderToggle` described the UI widget (a toggle). `userSortable` describes the capability (whether the user can reorder). The schema should express capabilities, not UI controls -- the mobile app decides how to present the toggle. Default changed to `true` because most grouped playlists benefit from user-controlled sort order.

### Removed: `progress` from SortRule fields

**Before:** SortRule.field allowed `playlistNumber`, `newestEpisodeDate`, `alphabetical`, `progress`
**After:** SortRule.field allows `playlistNumber`, `newestEpisodeDate`, `alphabetical`

**Why:** Progress (playback completion) is runtime state, not a static config concern. The schema defines defaults; the mobile app can sort by progress at runtime using its own state. Including it in the schema would couple config authoring to app-specific runtime concepts.

### Added: `episodeList.sort` (EpisodeSortRule)

**New $def:** `EpisodeSortRule` with fields: `publishedAt`, `episodeNumber`, `title`

**Why:** Episode ordering within a group was previously hardcoded (publishedAt ascending). Different podcasts benefit from different episode orderings -- some by episode number, some alphabetically. The mobile app may override at runtime, but the config should express the intended default. Can be overridden per-group via `GroupDef.episodeList.sort`.

### Added: `episodeList.titleExtractor` (TitleExtractor)

**Why:** Episode titles often contain redundant information already conveyed by the group context. For example, COTEN RADIO episodes titled "[62-15] Lincoln Arc -- Lincoln's Youth" repeat the arc name that's already shown as the group card title. `episodeList.titleExtractor` strips this redundancy for cleaner episode list display. Can be overridden per-group via `GroupDef.episodeList.titleExtractor`.

### Extracted: `YearBinding` to `$defs`

**Before:** `yearBinding` oneOf values defined inline in both `groupList.yearBinding` and `GroupDef.display.yearBinding`
**After:** `$defs/YearBinding` referenced via `$ref` from both locations

**Why:** Eliminates duplication. Both the definition-level and per-group override share the same enum values (`none`, `pinToYear`, `splitByYear`). Context-specific descriptions remain at the usage site via sibling `description` on the `$ref`.

### Extracted: `SortOrder` to `$defs`

**Before:** `order` field defined inline in both `SortRule` and `EpisodeSortRule` with identical enum values
**After:** `$defs/SortOrder` referenced via `$ref` from both sort rule types

**Why:** Eliminates duplication. Both group-level and episode-level sort rules share the same direction enum (`ascending`, `descending`).

### Removed: `GroupDef.display.sortOrder`

**Before:** `GroupDef.display.sortOrder` (enum: `ascending`, `descending`) overrode episode sort direction per-group
**After:** Use `GroupDef.episodeList.sort` instead (full `EpisodeSortRule` with field + order)

**Why:** Redundant with `GroupDef.episodeList.sort.order`. Having two fields that control episode sort direction at the same level creates ambiguous precedence. `episodeList.sort` provides strictly more control (field + order vs order-only).

### Kept at top level: `titleExtractor`, `prependSeasonNumber`

**Why:** Both apply to resolver results regardless of `playlistStructure` (subsequently renamed to `presentation`). In `split` (subsequently `separate`) mode they affect playlist titles; in `grouped` (subsequently `combined`) mode they affect group card titles. They are not grouped-only settings.

### Schema version: v1 -> v2

**$id:** `https://audiflow.app/schema/v1/playlist-definition.json` -> `https://audiflow.app/schema/v2/playlist-definition.json`

### Migration summary

| v1 field | v2 field |
|----------|----------|
| `contentType` | `presentation` |
| `contentType: "episodes"` | `presentation: "separate"` |
| `contentType: "groups"` | `presentation: "combined"` |
| `titleFilter` | `episodeFilters.require: [{ title: "..." }]` |
| `excludeFilter` | `episodeFilters.exclude: [{ title: "..." }]` |
| `requireFilter` | `episodeFilters.require: [{ title: "..." }]` (merged with titleFilter) |
| `yearHeaderMode` | `groupList.yearBinding` |
| `yearHeaderMode: "firstEpisode"` | `groupList.yearBinding: "pinToYear"` |
| `yearHeaderMode: "perEpisode"` | `groupList.yearBinding: "splitByYear"` |
| `showDateRange` | `groupList.showDateRange` |
| `customSort` | `groupList.sort` (single SortRule, not array) |
| `showSeasonNumber` | `prependSeasonNumber` |
| `showSortOrderToggle` | `groupList.userSortable` (default: true) |
| `episodeYearHeaders` | `episodeList.showYearHeaders` |
| `smartPlaylistEpisodeExtractor` | `numberingExtractor` |
| `SortRule.field: "progress"` | (removed -- runtime concern) |
| `GroupDef.episodeYearHeaders` | `GroupDef.episodeList.showYearHeaders` |
| `GroupDef.showDateRange` | `GroupDef.display.showDateRange` |
| (new) | `GroupDef.display.yearBinding` |
| (new) | `GroupDef.numberingExtractor` |
| (new) | `episodeList.sort` (EpisodeSortRule) |
| (new) | `episodeList.titleExtractor` (TitleExtractor) |
| (new) | `GroupDef.episodeList.sort` |
| (new) | `GroupDef.episodeList.titleExtractor` |
| (new $def) | `EpisodeSortRule` |
| (new $def) | `YearBinding` |
| (new $def) | `SortOrder` |
| `GroupDef.sortOrder` | (removed -- use `GroupDef.episodeList.sort` instead) |
