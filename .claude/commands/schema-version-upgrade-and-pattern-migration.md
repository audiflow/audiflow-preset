---
name: schema-version-upgrade-and-pattern-migration
description: Workflow command scaffold for schema-version-upgrade-and-pattern-migration in audiflow-smartplaylist.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /schema-version-upgrade-and-pattern-migration

Use this workflow when working on **schema-version-upgrade-and-pattern-migration** in `audiflow-smartplaylist`.

## Goal

Upgrades the playlist schema version and migrates all pattern files to the new schema syntax.

## Common Files

- `schema/playlist-definition.schema.json`
- `schema/VERSION`
- `.claude/skills/audiflow-playlist/references/schema-reference.md`
- `patterns/meta.json`
- `patterns/*/playlists/*.json`
- `patterns/*/meta.json`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Update schema/playlist-definition.schema.json to new version.
- Update schema/VERSION and related docs (e.g., schema-reference.md).
- Update patterns/meta.json to reference new schema fields.
- Migrate all patterns/*/playlists/*.json files to new schema syntax.
- Optionally update patterns/*/meta.json for new fields or order.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.