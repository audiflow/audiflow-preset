# Rename `playlistStructure` to `presentation` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename `playlistStructure` field to `presentation` with values `split` -> `separate` and `grouped` -> `combined` across schema, examples, data files, and docs.

**Architecture:** Pure rename -- no structural or behavioral changes. All references to the old field name and values are replaced with the new ones. CHANGELOG updated to document the rename.

**Tech Stack:** JSON schema, JSON data files, Markdown docs

---

### Task 1: Rename in schema definition

**Files:**
- Modify: `schema/playlist-definition.schema.json:11` (required array)
- Modify: `schema/playlist-definition.schema.json:50-62` (property definition)
- Modify: `schema/playlist-definition.schema.json:99` (groupList description reference)
- Modify: `schema/playlist-definition.schema.json:119` (titleExtractor/prependSeasonNumber description references)

- [ ] **Step 1: Rename field in `required` array**

Change line 11 from `"playlistStructure"` to `"presentation"`.

- [ ] **Step 2: Rename field key and update values/descriptions**

Replace the `playlistStructure` property block (lines 50-62) with:

```json
"presentation": {
  "description": "Determines how resolver results are presented to the user.",
  "oneOf": [
    {
      "const": "separate",
      "description": "Each resolver result becomes its own playlist, selectable from a dropdown. One definition produces many playlists, each containing episodes that share the same grouping key. Tapping a playlist shows its episodes directly. Best when each group (e.g., a season or year) should stand alone as an independent playlist."
    },
    {
      "const": "combined",
      "description": "All resolver results are collected as group cards inside a single playlist. One definition produces one playlist with sub-groups. Tapping the playlist shows group cards, and tapping a group card navigates to its episodes. Enables groupList settings (yearBinding, userSortable, showDateRange, sort). Best when groups should be browsed together under a unified playlist."
    }
  ]
}
```

- [ ] **Step 3: Update `groupList` description reference**

Change line 99 description from:
`"Only meaningful when playlistStructure is 'grouped'."`
to:
`"Only meaningful when presentation is 'combined'."`

- [ ] **Step 4: Update cross-references in other descriptions**

Search for any remaining `playlistStructure`, `'split'`, or `'grouped'` references in description strings within the schema and update them to use `presentation`, `'separate'`, `'combined'`.

Affected descriptions:
- `prependSeasonNumber` (line 95): `'split'` -> `'separate'`, `'grouped'` -> `'combined'`
- `titleExtractor` (line 90): `'split'` -> `'separate'`, `'grouped'` -> `'combined'`

- [ ] **Step 5: Validate schema is valid JSON**

Run: `python3 -c "import json; json.load(open('schema/playlist-definition.schema.json'))"`
Expected: No output (success)

- [ ] **Step 6: Commit**

```bash
git add schema/playlist-definition.schema.json
git commit -m "feat: rename playlistStructure to presentation with values separate/combined"
```

### Task 2: Rename in schema examples

**Files:**
- Modify: `schema/examples/season-number-resolver.json:6`
- Modify: `schema/examples/year-resolver.json:5`
- Modify: `schema/examples/title-discovery-resolver.json:5`
- Modify: `schema/examples/title-classifier-resolver.json:6`

- [ ] **Step 1: Update all 4 example files**

In each file, replace `"playlistStructure": "grouped"` with `"presentation": "combined"`.

- [ ] **Step 2: Validate all examples are valid JSON**

Run: `python3 -c "import json, glob; [json.load(open(f)) for f in glob.glob('schema/examples/*.json')]"`
Expected: No output (success)

- [ ] **Step 3: Commit**

```bash
git add schema/examples/
git commit -m "feat: rename playlistStructure to presentation in schema examples"
```

### Task 3: Rename in pattern data files

**Files:**
- Modify: `patterns/03ef94a3f8da/playlists/by_category.json:43`
- Modify: `patterns/03ef94a3f8da/playlists/by_year.json:44`
- Modify: `patterns/2e86c4b573b7/playlists/extras.json:229`
- Modify: `patterns/2e86c4b573b7/playlists/regular.json:35`
- Modify: `patterns/2e86c4b573b7/playlists/short.json:33`
- Modify: `patterns/350b6e89730f/playlists/extras.json:15`
- Modify: `patterns/350b6e89730f/playlists/others.json:14`
- Modify: `patterns/350b6e89730f/playlists/topics.json:25`
- Modify: `patterns/6e3ddeeaed0a/playlists/seasons.json:15`
- Modify: `patterns/9d1626c9a46b/playlists/others.json:11`
- Modify: `patterns/9d1626c9a46b/playlists/person.json:19`

- [ ] **Step 1: Update all 11 pattern files**

In each file, replace `"playlistStructure": "grouped"` with `"presentation": "combined"`.

- [ ] **Step 2: Validate all pattern files are valid JSON**

Run: `python3 -c "import json, glob; [json.load(open(f)) for f in glob.glob('patterns/*/playlists/*.json')]"`
Expected: No output (success)

- [ ] **Step 3: Commit**

```bash
git add patterns/
git commit -m "feat: rename playlistStructure to presentation in pattern data files"
```

### Task 4: Update CHANGELOG and docs

**Files:**
- Modify: `schema/docs/CHANGELOG.md` (add new entry, update old references)

- [ ] **Step 1: Add new CHANGELOG entry**

Add an unreleased section at the top of the CHANGELOG (after line 1), before the existing `## 2026-03-08` section:

```markdown
## Unreleased

### Renamed: `playlistStructure` -> `presentation`

**Values:** `split` -> `separate`, `grouped` -> `combined`

**Why:** The pair `split`/`grouped` lacked a coherent naming axis -- `split` described an action while `grouped` described a state. The new names sit on a clear presentation axis: `separate` means each resolver result is presented as its own playlist (selectable from a dropdown); `combined` means all results are presented as group cards inside a single playlist. The field name `presentation` reflects that this controls how results appear to the user, not internal structure.
```

- [ ] **Step 2: Update references in existing CHANGELOG entries**

Update lines in the v2 restructure section that reference the old names:
- Line 5: `contentType` -> `playlistStructure` becomes `contentType` -> `playlistStructure` -> `presentation`
  - Or leave as-is since it documents the v2 change. Add a note: "(subsequently renamed to `presentation` with values `separate`/`combined`)"
- Line 19: `playlistStructure: split` -> `presentation: separate`
- Line 42: `playlistStructure` is `'grouped'` -> `presentation` is `'combined'`
- Line 119: `playlistStructure` -> `presentation`, `'split'` -> `'separate'`, `'grouped'` -> `'combined'`
- Lines 129-131: Update migration table values

- [ ] **Step 3: Commit**

```bash
git add schema/docs/CHANGELOG.md
git commit -m "docs: add CHANGELOG entry for playlistStructure -> presentation rename"
```

### Task 5: Run schema validation

- [ ] **Step 1: Run full validation**

Run: `schema/scripts/validate.sh patterns/`
Expected: All files pass validation

- [ ] **Step 2: Verify no stale references remain**

Run: `grep -r "playlistStructure\|\"split\"\|\"grouped\"" schema/ patterns/ docs/ --include='*.json' --include='*.md'`
Expected: No matches (all references updated)

- [ ] **Step 3: If validation fails, fix and re-run**

The schema must be updated before data files can validate. If Task 1 was done correctly, validation should pass.
