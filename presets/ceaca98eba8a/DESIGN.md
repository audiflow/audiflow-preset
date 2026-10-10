# This is History

Feed: https://rss.pdrl.fm/5858fc/feeds.megaphone.fm/thisishistory
(also listed: https://feeds.megaphone.fm/thisishistory)
Pattern ID: `ceaca98eba8a` (md5 of feed URL, first 12 chars; the feed has no `podcast:guid`)

The feed fetch returns 403 for the default Python User-Agent; send a browser-like UA when analyzing it.

## Feed Characteristics

- 196 episodes since Aug 2022, by Dan Jones / Sony Music Entertainment.
- The feed carries two shows. "A Dynasty to Die For" (RSS seasons 1-10) covers the
  Plantagenets, roughly one reign per season, and is finished. "The Tudors" started in
  Sep 2026 as RSS season 11, but its titles restart at `S1 E1`. The channel title is now
  "This is History: The Tudors".
- Title formats:
  - Dynasty S1-S7: `Season 3 | 1. Softsword` (S3 E7 has a typo: `Season 3. | 7. ...`)
  - Dynasty S8-S10: `S8 E1 | A Hole in the Head`
  - Tudors: `S1 E1: The Red Rose and The White` (colon, not pipe)
  - Spin-offs: `The Iron King | 1. The Vespers`, `In Conversation | ...`,
    `Empire of Gold | ...`, `The Glass King | ...`, `1. A Nativity to Die For -- ...`
- RSS season tags are unreliable for grouping: spin-offs are tagged into the
  surrounding Dynasty season (e.g. The Iron King = S4 E13-18), and most trailers have
  no season tag. All grouping is therefore title-based.
- Episode titles never name the monarch, so season names cannot be extracted. They
  are hand-written from the trailer descriptions ("This season we meet Edward II").

## Playlist Breakdown

Claim order: `the_tudors` -> `dynasty` -> `spinoffs` (all filtered) -> `extras` (catch-all).

### `the_tudors`

- Filter: `^S\d+ E\d+\s*:` (the colon separates it from Dynasty S8-S10) or the
  launch trailer `Who's afraid of Henry Tudor?`.
- Classifiers: `S1 Henry VII`, then `New season` as a catch-all so that episodes of a
  future season stay visible until someone adds a classifier for it.

### `dynasty`

- Filter: `^Season \d+\.?\s*\|`, `^S\d+ E\d+\s*\|`, or a title ending in
  `Dynasty to Die For` (season trailers).
- One classifier per season. Each pattern matches both the episode prefix and the
  season's trailer, whose number is spelled either as a digit (`Season 5 of`) or a
  word (`Season Six of`). `^Season 1\s*\|` must keep the pipe so it does not match
  `Season 10`.
- Season names (from trailer descriptions):

  | Season | Name | Note |
  |---|---|---|
  | 1 | Henry II & Eleanor of Aquitaine | |
  | 2 | Richard the Lionheart | |
  | 3 | King John | |
  | 4 | Henry III & Simon de Montfort | |
  | 5 | Edward II | E1 opens with the old Edward I |
  | 6 | Edward III | |
  | 7 | Richard II | |
  | 8 | Henry IV & Henry V | E1 is Henry IV, trailer is Henry V |
  | 9 | Henry VI | |
  | 10 | Edward IV & Richard III | ends at Bosworth |

- Episode rows drop the `Season N |` prefix; for the `S8 E1 |` format the episode
  number is kept as `1. Title` to match the S1-S7 rows.

### `spinoffs`

- Filter and classifiers on the series name: The Iron King, In Conversation,
  Empire of Gold, The Glass King, A Nativity to Die For (chronological order).
- Episode rows drop the `Series |` prefix.

### `extras`

- `Other podcasts`: cross-promotions (`You may also like`, This is History PLUS,
  Draptomaniax).
- `Bonus & talks`: everything else, mainly the untitled talk episodes tagged
  S9 E14-19 and S10 E14-17.

## Maintenance

When a new Tudors season starts:

1. Add a classifier `^S{n} E\d+\s*:` (plus its trailer title) before `New season`.
2. If the trailer title does not match `^S\d+ E\d+\s*:`, also add it to the playlist's
   `episodeFilters.require` alternation. Otherwise the filter never claims the trailer
   and it falls through to `extras`.

This is the update that `audiflow-preset-curator` is meant to automate.

Classifier patterns spell out both letter cases where titles vary (`Empire [Oo]f Gold`)
because the editor preview used to match them case-sensitively while the app does not
(fixed in audiflow/audiflow-preset-editor#128). The title-cleanup extractors stay
case-sensitive, so they need the same treatment.
