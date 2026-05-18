# Editor versioning strategy

The data repo's CI uses pre-compiled editor CLI binaries for validation and version bumping. Binaries are published as GitHub Releases with mutable major-version tags.

## Binary release model

The editor publishes `audiflow-editor` binaries via GitHub Releases using two tag types:

| Tag | Type | Example | Purpose |
|-----|------|---------|---------|
| `v7.1.0` | immutable | specific release | Reproducibility, changelogs |
| `v7` | mutable | always points to latest v7.x | CI consumption |

This follows the same convention as GitHub Actions (e.g., `actions/checkout@v4`).

### Editor release workflow

1. `cargo build --release` produces `audiflow-editor` for linux-x64
2. Create GitHub Release for the immutable tag (`v7.1.0`) with binary attached
3. Move the mutable `v7` tag to the new commit
4. Update the `v7` release to attach the latest binary

### Data repo CI consumption

The data repo's deploy and validate workflows download the binary from the mutable tag:

```yaml
- run: |
    gh release download v7 \
      --repo audiflow/audiflow-preset-editor \
      --pattern 'audiflow-editor-x86_64-unknown-linux-gnu' \
      --output audiflow-editor
    chmod +x audiflow-editor
- run: ./audiflow-editor validate presets/
- run: ./audiflow-editor bump-versions presets/ HEAD~1
```

No Rust toolchain, no clone, no `cargo build` required.

## Version branch model

The editor also maintains version branches for development:

| Branch | Purpose |
|--------|---------|
| `main` | Latest development, may contain unreleased schema changes |
| `v7` | Stable tooling for schema v7 |

When a new schema version ships:
1. Create `v{N}` branch from `main` (or from `v{N-1}` if incremental)
2. Schema changes go to `main` first, then to the new version branch
3. Bug fixes to old versions are cherry-picked to the relevant `v{N}` branch
4. Each cherry-pick triggers a minor release (e.g., `v7.1.0` -> `v7.2.0`)

## What lives on version branches

- `crates/preset_core/assets/*.schema.json` -- schema definitions (SSoT)
- `crates/preset_core/` -- Rust models matching the schema
- `crates/preset_cli/` -- CLI tools (validate, bump_versions)
- `packages/preset_react/` -- Zod schemas for the editor UI
