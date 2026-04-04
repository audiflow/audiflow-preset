# Coten Radio

History podcast by COTEN Inc. Three hosts discuss historical topics in multi-episode series, with occasional guest episodes and standalone specials.

## Feed characteristics

The RSS feed uses structured numbering in titles (e.g., `【55-5】`), but the metadata has gaps -- some episodes have missing or incorrect season/episode numbers in RSS fields. Because the feed is not fully consistent, title strings are the primary source for identifying and ordering episodes.

Title formats observed in the feed:

- Regular: `【COTEN RADIO {テーマ}編 {season}-{episode}】` (e.g., `【COTEN RADIO ガンディー編 55-5】`)
- Short: `【COTEN RADIOショート {テーマ} {episode}】`
- Extras: inconsistent -- `番外編＃{n}`, `特別編`, guest names, or free-form titles

Some episodes lack the `【season-episode】` bracket pattern entirely and need fallback extraction.

## Playlist breakdown

Three playlists, ordered by priority:

| Playlist | What it captures | Why separate |
|----------|-----------------|--------------|
| `regular` (pri=10) | Numbered main series (`【{s}-{e}】`) | Core content, reliable title structure, grouped by theme |
| `short` (pri=20) | COTEN RADIO ショート episodes | Same numbering scheme but different series line, needs own filter |
| `extras` (pri=30) | Everything else -- 番外編, 特別編, guest episodes | Catch-all for episodes that don't fit the numbered series |

Priority determines claim order: regular claims first, then short, then extras gets the remainder.

## Episode identification

### regular and short

Both parse season/episode from title using `【({season})-({episode})】`. When this pattern is absent:

- **regular**: falls back to `({episode})】` with `fallbackSeasonNumber: 0`
- **short**: falls back to `【番外編[＃#]({episode})】` (some short episodes use 番外編 numbering)

Both ultimately fall back to RSS metadata (`fallbackToRss: true`) as a last resort, though this data is unreliable.

### Title extraction

Group names (the theme of a multi-episode series) are extracted from titles:

- Primary: `【COTEN RADIO {theme}編 {n}】` -- captures `{theme}`
- Fallback: `【COTEN RADIO {theme} {n}】` -- for titles without `編` suffix
- Default: `その他` when neither pattern matches

### extras

No automated episode extraction. Uses `category` resolver -- episodes are matched to groups by regexp against their title, not by RSS metadata.

## Grouping decisions

### regular and short

Grouped by extracted theme name (the `編` series). Sorted by `playlistNumber` ascending so series appear in broadcast order. Year-bound (`pinToYear`) to keep the timeline clear.

### extras

番外編 and 特別編 episodes are topically random, but many cluster around a guest or theme. These are grouped explicitly using regexp patterns against episode titles.

Groups fall into three tiers:

**Guest episodes** -- multi-episode conversations with a named guest. Each group's regexp matches the guest's name in the title. Examples:
- `室越龍之介` (人類学って何？)
- `中村哲` (「一隅を照らす」)
- `若新雄純` (appears twice as `wakamiya1` and `wakamiya2` -- different series, different years)

**Topic clusters** -- episodes about a specific subject, not tied to a single guest:
- `ウクライナ戦争` (uses alternation regexp to match varied title wording across multiple emergency episodes)
- `財閥の歴史`
- `仏教のこと、龍源さんに聞こう`

**Catch-all buckets** -- at the bottom of the group list:
- `特別編` -- matches episodes with `特別編` in the title
- `番外編` -- matches `番外編[#＃]` (numbered 番外編 episodes)
- `その他` -- no pattern, catches everything unmatched

The catch-all groups use `splitByYear` year binding and descending sort (newest first), since they accumulate unrelated episodes over time. Guest/topic groups with few episodes disable year headers (`showYearHeaders: false`) to avoid visual noise.
