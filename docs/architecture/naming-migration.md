# Naming migration: smartplaylist -> preset

## Why

Users encountering "smart playlist" expect AI-driven or dynamic playlist
generation. The feature is pre-defined, rules-based per-podcast
configuration. The name oversold the capability. "Preset" is honest:
each podcast has one or more pre-defined configurations that the app
consumes.

## Glossary

| Old | New |
|-----|-----|
| smartplaylist (repo, paths, docs) | preset |
| smart_playlist (snake / Dart filenames) | preset |
| smartPlaylist (camel) | preset |
| SmartPlaylist (PascalCase types) | Preset |
| smart playlist (UI strings, prose) | preset |
| pattern / patternId / PatternMeta (JSON + Rust) | preset / presetId / PresetMeta |
| patterns/ (data directory on env branches) | presets/ |
| pattern-index.schema.json / pattern-meta.schema.json | preset-index.schema.json / preset-meta.schema.json |
| playlist-definition.schema.json | playlist-definition.schema.json *(unchanged — "playlist" inside a preset stays valid)* |
| sp_core / sp_cli / sp_server (Rust crates) | preset_core / preset_cli / preset_server |
| audiflow-editor (release binary name) | audiflow-editor (kept for v7; rename deferred to a later major -- see Phase 1 in the [migration plan](../superpowers/plans/2026-05-18-rename-smartplaylist-to-preset.md)) |

The container is a **preset**. A preset contains **playlists**. On disk, a preset is `presets/{presetId}/` containing `meta.json` plus `playlists/*.json`. "Playlist" remains a valid term for the curated track-group entity inside a preset.

## Repository renames (scheduled in Phase 4)

| Old | New |
|-----|-----|
| audiflow-smartplaylist | audiflow-preset |
| audiflow-smartplaylist-editor | audiflow-preset-editor |

## Binary compatibility

The v7 `audiflow-editor` binary's `bump-versions` subcommand auto-detects
`patterns/` vs `presets/`, so a single release services both legacy v6
branches and the renamed v7 branches.

## Branch / URL mapping

| Env | Old branch (kept alive through Phase 5) | New branch | Old URL path | New URL path |
|-----|-----------------------------------------|------------|--------------|--------------|
| dev | dev/v6 | dev/v7 | assets-dev/v6/patterns/* | assets-dev/v7/presets/* |
| stg | stg/v6 | stg/v7 | assets-stg/v6/patterns/* | assets-stg/v7/presets/* |
| prod | prod/v6 | prod/v7 | assets/v6/patterns/* | assets/v7/presets/* |

## Phase index

- Phase 0: this document
- Phase 1: editor schema + Rust rename, release v7 binaries
- Phase 2: this repo dev/v7, stg/v7, prod/v7 branches + workflows
- Phase 3: app rename + URL cutover
- Phase 4: GitHub repo renames
- Phase 5: v6 deprecation

## See also

- [Full migration plan](../superpowers/plans/2026-05-18-rename-smartplaylist-to-preset.md)
