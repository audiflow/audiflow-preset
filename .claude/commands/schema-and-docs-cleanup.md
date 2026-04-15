---
name: schema-and-docs-cleanup
description: Workflow command scaffold for schema-and-docs-cleanup in audiflow-smartplaylist.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /schema-and-docs-cleanup

Use this workflow when working on **schema-and-docs-cleanup** in `audiflow-smartplaylist`.

## Goal

Removes deprecated fields or aliases from the schema and updates documentation to match.

## Common Files

- `schema/playlist-definition.schema.json`
- `.claude/skills/audiflow-playlist/references/schema-reference.md`
- `docs/specs/file-structure.md`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Remove deprecated fields/aliases from schema/playlist-definition.schema.json.
- Update .claude/skills/audiflow-playlist/references/schema-reference.md to match new schema.
- Update docs/specs/file-structure.md if file structure or accepted values change.
- Commit schema and docs changes together.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.