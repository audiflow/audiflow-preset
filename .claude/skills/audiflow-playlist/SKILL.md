---
name: audiflow-playlist
description: Create and update audiflow smart playlist patterns and definitions. Use this skill whenever the user wants to create a new playlist pattern, modify an existing pattern, analyze a podcast RSS feed for grouping, search for podcast feeds, validate patterns, or discuss any aspect of the audiflow playlist schema (resolver types, title extractors, episode filters, groups, numbering). Also trigger when the user mentions pattern IDs, feed URLs, the audiflow-editor CLI, or refers to files under patterns/. Even if the user just says "add a podcast" or "new pattern" or names a specific podcast, this skill applies.
---

# audiflow-playlist

Create and manage smart playlist patterns for the audiflow ecosystem. This skill covers the full workflow: searching for podcasts, analyzing RSS feeds, writing pattern JSON, and validating with the editor CLI.

## Quick Reference

### File structure
```
patterns/
  meta.json                         # Root index (all patterns)
  {patternId}/
    meta.json                       # Pattern meta (feed matching, playlist order)
    DESIGN.md                       # Design rationale (optional but recommended)
    playlists/
      {playlistId}.json             # Playlist definition (grouping, display)
```

### Four resolver types
| Resolver | Groups by | Best for |
|----------|-----------|----------|
| `seasonNumber` | Season number (title or RSS) | Podcasts with S01E01 or bracket numbering |
| `year` | Publication year | Long-running podcasts, no clear title pattern |
| `titleDiscovery` | Auto-detected title patterns | Story arcs, recurring series |
| `titleClassifier` | Regex rules you define | Bracket prefixes, category markers, mixed formats |

### Two presentation modes
| Mode | Behavior |
|------|----------|
| `separate` | Each group becomes its own selectable playlist |
| `combined` | Groups shown as cards inside a single playlist |

For full schema details, read `references/schema-reference.md`.

---

## Workflow: Creating a New Pattern

### Step 1: Find the podcast feed

If the user provides a feed URL, skip to Step 2. Otherwise, search by title:

```bash
python3 <skill_path>/scripts/search-feeds.py "podcast name" --country jp
```

The script uses the iTunes Search API. Adjust `--country` as needed (us, gb, etc.). Present results and let the user pick the right podcast. Note the `feedUrl` from the chosen result.

### Step 2: Analyze the feed

```bash
python3 <skill_path>/scripts/analyze-feed.py "<feed_url>"
```

This fetches the RSS feed and reports:
- Feed metadata (title, episode count, date range)
- RSS season/episode tag coverage
- Title numbering patterns detected
- Bracket formats
- Recurring title prefixes
- Suggested resolver type with reasoning
- Suggested groups (for titleClassifier)
- Sample episode titles

Review the output carefully. The suggestions are starting points -- episode titles can be messy and the heuristics may miss nuances. Always look at the sample titles yourself and consider:
- Are there distinct series/formats that should be separate playlists?
- Which episodes should be filtered out (reruns, trailers, ads)?
- Do title patterns have enough consistency for regex extraction?

### Step 3: Derive the pattern ID

The ID is deterministic:
```python
import hashlib
# Prefer podcastGuid when available
source = podcast_guid if podcast_guid else feed_url
pattern_id = hashlib.md5(source.encode()).hexdigest()[:12]
```

### Step 4: Design the pattern

Before writing JSON, think through these decisions:

**How many playlists?** Look at the episode types. A podcast with regular episodes, bonus content, and live recordings might need 3 playlists. A simple seasonal podcast might need just 1.

**Episode ownership**: Playlists with `episodeFilters` claim episodes first, in the order listed in pattern meta's `playlists` array. Filter-less playlists get the remainder. Use this to separate distinct episode types.

**Resolver choice per playlist**: Different playlists under the same pattern can use different resolvers. The "regular series" playlist might use `seasonNumber` while the "extras" playlist uses `titleClassifier`.

**Resolver selection guide** -- choose based on the podcast's structure, not just what metadata exists:
- `seasonNumber`: Use when RSS season tags are reliable (high coverage) AND each season maps to a meaningful unit (a story arc, a topic, a guest run). Many seasons (10+) make this worthwhile. If the podcast only has 2-3 RSS seasons, this gives too few groups.
- `year`: Use for long-running podcasts (200+ episodes) where no clear title patterns exist. Also good as a secondary "alternative view" playlist alongside a primary grouping.
- `titleDiscovery`: Use when episodes have recurring title patterns that naturally form groups (professor names, series arcs, recurring segments) but there are too many groups to enumerate manually, or new groups appear regularly without pattern changes.
- `titleClassifier`: Use when you need explicit control over grouping rules -- bracket prefixes, category markers, or mixed formats where regex rules define each group. Best when the number of groups is stable and manageable.

**Group design for titleClassifier**: Groups evaluate in order, first match wins. Put specific patterns first, catch-all (no pattern) last. Consider:
- Guest episodes (match guest name in title)
- Topic clusters (match recurring topic keywords)
- Format variants (daily, weekly, special editions)
- Catch-all bucket at the end

If the user already has a specific structure in mind, follow their design. The analysis from Step 2 is a suggestion, not a prescription.

### Step 5: Write the JSON files

Create three levels of files:

**1. Pattern directory and meta**:
```
patterns/{patternId}/meta.json
```
```json
{
  "dataVersion": 1,
  "id": "{patternId}",
  "podcastGuid": "guid-if-available",
  "feedUrls": ["https://..."],
  "yearGroupedEpisodes": false,
  "playlists": ["playlist_id_1", "playlist_id_2"]
}
```

Set `yearGroupedEpisodes: true` for podcasts with 200+ episodes where year grouping helps navigation in the main episode list.

**2. Playlist definitions**:
```
patterns/{patternId}/playlists/{playlistId}.json
```

Refer to `references/schema-reference.md` for all field options. Here are templates for common setups:

**Understanding the two titleExtractors**: There are two different places titleExtractor appears, and they do completely different things:
- **Top-level `titleExtractor`**: Generates **group titles** (the name of a season or year). It runs against a representative episode from each group. For a seasonNumber resolver, this produces the label for each season card -- e.g., "Lincoln Arc" or "Season 5". If the podcast doesn't have named series arcs, use `"source": "seasonNumber"` with a template like `"シーズン {value}"` or `"Season {value}"` to generate clean season labels.
- **`episodeList.titleExtractor`**: Transforms **episode display names** within groups. It strips redundant info (like the series name) that's already conveyed by the group context. For example, stripping `【COTEN RADIO リンカン編15】` down to just the episode title.

Do not confuse these. A pattern that extracts episode-level text (like `「(.+?)」`) should go in `episodeList.titleExtractor`, not at the top level.

**seasonNumber + combined** (most common for season-based podcasts):
```json
{
  "id": "seasons",
  "displayName": "Seasons",
  "resolverType": "seasonNumber",
  "presentation": "combined",
  "titleExtractor": {
    "source": "title",
    "pattern": "regex to extract the SERIES/SEASON NAME from a representative episode title",
    "group": 1,
    "fallback": {
      "source": "seasonNumber",
      "template": "Season {value}"
    }
  },
  "episodeList": {
    "titleExtractor": {
      "source": "title",
      "pattern": "regex to clean up EPISODE DISPLAY NAMES (strip redundant series prefix etc.)",
      "group": 1
    }
  },
  "groupList": {
    "sort": { "field": "playlistNumber", "order": "ascending" },
    "showDateRange": true,
    "yearBinding": "pinToYear"
  }
}
```

**titleClassifier + combined** (most common for category-based podcasts):
```json
{
  "id": "by_category",
  "displayName": "Categories",
  "resolverType": "titleClassifier",
  "presentation": "combined",
  "groups": [
    { "id": "series_a", "displayName": "Series A", "pattern": "regex" },
    { "id": "series_b", "displayName": "Series B", "pattern": "regex" },
    { "id": "other", "displayName": "Other" }
  ]
}
```

**Catch-all playlist** (claims remaining episodes):
```json
{
  "id": "extras",
  "displayName": "Extras",
  "resolverType": "titleClassifier",
  "presentation": "combined",
  "groups": [
    { "id": "bonus", "displayName": "Bonus", "pattern": "bonus|extra" },
    { "id": "other", "displayName": "Other" }
  ]
}
```

**3. Update the root index** (`patterns/meta.json`):

Add an entry to the `patterns` array:
```json
{
  "id": "{patternId}",
  "dataVersion": 1,
  "displayName": "Podcast Title",
  "feedUrlHint": "distinctive-part-of-feed-url",
  "playlistCount": 2
}
```

The `feedUrlHint` should be a substring that uniquely identifies the feed. For Anchor feeds: `anchor.fm/s/{id}`. For Megaphone: `megaphone.fm/...`. Pick the most distinctive part.

### Step 6: Write a DESIGN.md

Create `patterns/{patternId}/DESIGN.md` documenting:
- Feed characteristics (title format variations, metadata gaps)
- Playlist breakdown (what each captures and why)
- Episode identification strategy (primary patterns, fallbacks)
- Grouping decisions (why this structure, catch-all strategy)

This helps future maintainers understand the reasoning behind regex choices.

### Step 7: Preview in browser

After writing the pattern files, launch the editor web UI so the user can see the actual grouping result with live RSS data:

```bash
# Start the editor in the background (downloads binary automatically)
nohup ./editor.sh > /dev/null 2>&1 &
EDITOR_PID=$!
```

Tell the user: "Editor is running at http://localhost:8080 -- open it to preview your pattern with live feed data. Let me know when you're done and I'll stop the server."

When the user is done previewing:
```bash
kill $EDITOR_PID 2>/dev/null
```

If the preview reveals issues (wrong grouping, mismatched regex, episodes in the wrong playlist), fix the JSON files and reload the browser -- the editor picks up file changes.

The preview step is optional but recommended for new patterns. Skip it if the user just wants to validate and commit.

### Step 8: Validate

```bash
schema/scripts/validate.sh patterns/
```

This downloads the `audiflow-editor` binary (matching `schema/VERSION`) and runs validation. Fix any errors before committing.

---

## Workflow: Updating an Existing Pattern

1. Read the existing pattern files and DESIGN.md
2. Understand what needs to change (new playlist, updated groups, filter tweaks)
3. If modifying regex patterns, analyze sample titles first -- run `analyze-feed.py` to see current episode titles
4. Make changes, keeping the DESIGN.md in sync
5. Preview with `./editor.sh` to verify grouping looks correct in the browser (optional)
6. Validate with `schema/scripts/validate.sh patterns/`
7. Bump `dataVersion` is handled by CI (`audiflow-editor bump-versions`), but for local testing set it manually

---

## Editor CLI Commands

The `audiflow-editor` binary is downloaded automatically by the scripts in `schema/scripts/`.

| Command | Usage | Purpose |
|---------|-------|---------|
| `validate` | `audiflow-editor validate patterns/` | Validates all JSON against schemas |
| `bump-versions` | `audiflow-editor bump-versions HEAD~1` | Auto-increment dataVersion for changed files |
| `--version` | `audiflow-editor --version` | Show binary version |

Schema version is tracked in `schema/VERSION` (currently v4). The binary is fetched from `audiflow/audiflow-smartplaylist-editor` GitHub releases, cached in `.cache/bin/{version}/`.

---

## Title Pattern Conventions

### Japanese podcasts

Common patterns to look for:
- Full-width brackets: `【content】` -- very common for categorization
- Numbered brackets: `【{season}-{episode}】` -- structured numbering
- Date brackets: `【{month}月{day}日】` -- daily/weekly shows
- Series markers: `{series}編`, `{topic}シリーズ`
- Special markers: `番外編`, `特別編`, `ゲスト回`
- Counter words: `第{n}回`, `第{n}話`

### English podcasts

- `S{n}E{n}` or `Season {n}, Episode {n}` -- standard season/episode
- `{Series Title} - {Episode}` or `{Series Title} | {Episode}` -- delimiter-based
- `Ep. {n}:`, `Episode {n}:`, `#{n}` -- episode numbering
- `Best of`, `Encore:`, `Replay:` -- rerun markers (often filtered out)
- `Bonus:`, `Extra:`, `Special:` -- special content markers

### Writing robust regex patterns

- Escape special regex characters in literal text
- Use `\\s*` or `\\s+` for flexible whitespace
- Use non-greedy quantifiers (`+?`, `*?`) to avoid over-matching
- For Japanese brackets, match both half-width `[]` and full-width `【】`
- Test patterns against the sample titles from `analyze-feed.py`
- Remember: patterns in episodeFilters and groups are case-insensitive

---

## Common Pitfalls

1. **Forgetting the catch-all group**: titleClassifier groups without a catch-all will leave unmatched episodes ungrouped. Always add a pattern-less group at the end.

2. **Pattern order matters**: Groups evaluate first-to-last. Put narrow patterns before broad ones, or episodes get claimed by the wrong group.

3. **feedUrlHint too generic**: A hint like `rss` matches everything. Use the most distinctive URL segment.

4. **Missing `id` match**: The `id` in meta.json must match the directory name. The `id` in playlist JSON must match the filename.

5. **episodeFilters logic**: `require` is AND across rules, `exclude` is OR. A definition with both `require` and `exclude` first includes matching episodes, then removes excluded ones.

6. **titleExtractor on titleClassifier**: titleClassifier ignores the top-level titleExtractor. Group names come from GroupDef.displayName. But `episodeList.titleExtractor` still works for transforming episode titles within groups.

7. **Confusing the two titleExtractors**: The top-level `titleExtractor` generates **group titles** (season/series names). The `episodeList.titleExtractor` transforms **episode display names**. Putting an episode-title pattern (like `「(.+?)」`) at the top level produces nonsensical group names. When the podcast has no named arcs, use `"source": "seasonNumber"` with a template for clean group labels.
