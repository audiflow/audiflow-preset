```markdown
# audiflow-smartplaylist Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development patterns, coding conventions, and operational workflows for contributing to the `audiflow-smartplaylist` repository. The project is a Python-based system for defining, validating, and managing smart playlist patterns using JSON schemas and pattern files. It emphasizes schema-driven development, consistent pattern management, and robust documentation practices.

## Coding Conventions

- **File Naming:**  
  Use `camelCase` for Python files and JSON files.  
  *Example:*  
  ```
  playlistManager.py
  patternMeta.json
  ```

- **Import Style:**  
  Use relative imports within Python modules.  
  *Example:*  
  ```python
  from .utils import validatePattern
  ```

- **Export Style:**  
  Use named exports (explicitly listing functions/classes to export).  
  *Example:*  
  ```python
  __all__ = ["validatePattern", "loadSchema"]
  ```

- **Commit Messages:**  
  Follow [Conventional Commits](https://www.conventionalcommits.org/) with these prefixes: `chore`, `feat`, `refactor`, `fix`.  
  *Example:*  
  ```
  feat: add support for playlist sorting by genre
  ```

- **JSON Patterns:**  
  - Use consistent key order and field placement.
  - Update all related meta files when adding or changing patterns.

## Workflows

### Schema Version Upgrade and Pattern Migration
**Trigger:** When a new schema version is released and all patterns must be updated to comply.  
**Command:** `/upgrade-schema`

1. Update `schema/playlist-definition.schema.json` to the new version.
2. Update `schema/VERSION` and related documentation (e.g., `.claude/skills/audiflow-playlist/references/schema-reference.md`).
3. Update `patterns/meta.json` to reference new schema fields.
4. Migrate all `patterns/*/playlists/*.json` files to the new schema syntax.
5. Optionally update `patterns/*/meta.json` for new fields or order.
6. Commit all changes together.

*Example commit message:*  
```
chore: upgrade schema to v2.1 and migrate all pattern files
```

---

### Add or Update Pattern
**Trigger:** When adding a new playlist pattern or making significant changes to an existing pattern.  
**Command:** `/add-pattern`

1. Create or update `patterns/<pattern-id>/meta.json`.
2. Create or update `patterns/<pattern-id>/playlists/*.json`.
3. Optionally add or update `patterns/<pattern-id>/DESIGN.md`.
4. Update `patterns/meta.json` if global pattern metadata changes.
5. Commit all related files together.

*Example directory structure:*  
```
patterns/
  jazzVibes/
    meta.json
    playlists/
      chillJazz.json
      upbeatJazz.json
    DESIGN.md
```

---

### Schema and Docs Cleanup
**Trigger:** When deprecated schema fields or aliases are no longer needed.  
**Command:** `/cleanup-schema-docs`

1. Remove deprecated fields/aliases from `schema/playlist-definition.schema.json`.
2. Update `.claude/skills/audiflow-playlist/references/schema-reference.md` to match the new schema.
3. Update `docs/specs/file-structure.md` if file structure or accepted values change.
4. Commit schema and docs changes together.

*Example commit message:*  
```
refactor: remove deprecated 'genreAlias' field from schema and docs
```

---

### Pattern Field Normalization
**Trigger:** When introducing or enforcing a new field order or normalization rule for pattern files.  
**Command:** `/normalize-pattern-fields`

1. Update all `patterns/*/meta.json` and `patterns/*/playlists/*.json` to match the new field order.
2. Optionally update `patterns/meta.json` for global consistency.
3. Commit all normalization changes together.

*Example before/after for field order:*
```json
// Before
{
  "name": "Chill Jazz",
  "id": "chillJazz",
  "description": "Relaxed jazz tracks"
}

// After
{
  "id": "chillJazz",
  "name": "Chill Jazz",
  "description": "Relaxed jazz tracks"
}
```

## Testing Patterns

- **Test File Pattern:**  
  Test files follow the `*.test.*` naming convention.  
  *Example:*  
  ```
  playlistManager.test.py
  ```

- **Framework:**  
  The testing framework is not explicitly specified. Use standard Python testing practices (e.g., `unittest` or `pytest`).

- **Test Example:**  
  ```python
  def test_validatePattern_valid():
      assert validatePattern(validPattern) is True
  ```

## Commands

| Command                  | Purpose                                                               |
|--------------------------|-----------------------------------------------------------------------|
| /upgrade-schema          | Upgrade schema version and migrate all pattern files                  |
| /add-pattern             | Add a new playlist pattern or update an existing one                  |
| /cleanup-schema-docs     | Remove deprecated schema fields/aliases and update documentation      |
| /normalize-pattern-fields| Normalize field order and placement across all pattern files          |
```
