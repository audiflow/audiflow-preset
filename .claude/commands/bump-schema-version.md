Bump the schema version across all files in this repository.

## Steps

1. Read the current version from `schema/VERSION` (a single integer on line 1).
2. Compute the new version: current + 1.
3. Update all five files atomically:

| File | What to change |
|------|----------------|
| `schema/VERSION` | Replace the integer with the new version |
| `patterns/meta.json` | `"schemaVersion": <old>` to `"schemaVersion": <new>` |
| `schema/pattern-index.schema.json` | `$id` URI: replace `v<old>` with `v<new>` |
| `schema/pattern-meta.schema.json` | `$id` URI: replace `v<old>` with `v<new>` |
| `schema/playlist-definition.schema.json` | `$id` URI: replace `v<old>` with `v<new>` |

4. After all edits, print a summary table showing the old and new version for each file.

## Rules

- Do NOT commit. Only edit the files.
- Fail loudly if `schema/VERSION` is missing or not a valid integer.
- Use the Edit tool for JSON files to avoid reformatting.
