# 日本一たのしい哲学ラジオ

Feed: https://anchor.fm/s/e4d354fc/podcast/rss
Pattern ID: `ccf7c0050e3f` (md5 of feed URL, first 12 chars)

## Feed Characteristics

- 153 episodes since July 2023.
- No RSS season/episode tags (0% coverage). Numbering must come from the title.
- 99% of titles end with a global hash counter `#N`.
- Regular series episodes use the convention `【{シリーズ名}{回数}】...` -- e.g.
  `【アダム・スミス8】`, `【カント13】`, `【日本の法律11】`,
  `【ネオ高等遊民さんゲスト回4】`, `【資本主義との距離感6】`.
- Specials use circled digits inside brackets (`【特別編①】`〜`【特別編⑤】`),
  so they do **not** match `【\D+\d+】` and naturally fall outside "regular".
- Chat episodes use `【雑談回】` (with no inner digit) and sometimes appear as a
  trailing tag rather than a leading prefix.

## Playlist Breakdown

### `regular` (レギュラーシリーズ)

- Filter: title matches `【\D+\d+】` and does **not** contain `【雑談`.
- Grouping: `titleDiscovery` with hint `【(\D+)\d+】`. Each series name (アダム・
  スミス, カント, 日本の法律, ...) becomes a group.
- Group title: extracted from the same bracket pattern, group 1.
- Episode title cleanup: strip the leading `【...】` bracket so the group context
  is not duplicated in the row label.
- Episodes sorted by published date ascending so series flow 1 → N.

### `extras` (その他)

- No filter -- claims everything not taken by `regular` (specials, chat
  episodes, listener-mail episodes, etc.).
- `titleClassifier` with three buckets, evaluated in order:
  1. `雑談回` -- matches `【雑談` or trailing `雑談回】`.
  2. `特別編` -- matches `【特別編` (covers `【特別編①】`〜`【特別編⑤】`).
  3. `その他` -- catch-all.
- Sorted by newest episode date so recent extras surface first.

## Why This Structure

Two playlists keep the surface clean: regular series episodes group by topic
and read in series order, while one-off content stays out of the way under
`extras`. The user-supplied regex `【(\D+)\d+】` is the load-bearing rule -- it
naturally separates the structured series episodes from specials (circled
digits) and chat episodes (no digit at all), so the explicit `【雑談` exclusion
is a defensive guard rather than a primary filter.
