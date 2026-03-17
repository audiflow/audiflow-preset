# audiflow-smartplaylist

Smart playlist configuration data for the [audiflow](https://github.com/audiflow) podcast ecosystem. Static JSON files deployed to GitHub Pages and fetched by the app at runtime.

## How it works

```
Editor (local) --> git push --> CI validate & deploy --> GitHub Pages --> App fetches
```

The [audiflow-smartplaylist-editor](https://github.com/audiflow/audiflow-smartplaylist-editor) generates playlist configs locally. Users commit and push to this repo. CI validates the JSON, bumps `dataVersion`, and deploys to GitHub Pages.

## Branch and deployment model

`main` holds infrastructure only (workflows, docs, scripts). Data lives on environment/version branches:

| Branch | Deploy path | URL |
|--------|------------|-----|
| `prod/v1` | `/assets/v1/` | `audiflow.github.io/audiflow-smartplaylist/assets/v1/` |
| `prod/v2` | `/assets/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets/v2/` |
| `stg/v2` | `/assets-stg/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets-stg/v2/` |
| `dev/v2` | `/assets-dev/v2/` | `audiflow.github.io/audiflow-smartplaylist/assets-dev/v2/` |

Promotion flow: `dev/v{N}` -> PR -> `stg/v{N}` -> PR -> `prod/v{N}`

Multiple schema versions can be served concurrently.

## File structure (on data branches)

```
patterns/
  meta.json                    # Root index: dataVersion, schemaVersion, pattern list
  {patternId}/
    meta.json                  # Pattern metadata: feed URLs, playlist IDs
    playlists/
      {playlistId}.json        # Playlist definition: resolver, grouping, display rules
schema/
  *.schema.json                # Vendored JSON schemas (SSoT is in the editor repo)
  scripts/validate.sh          # Local validation (requires uv)
```

The app loads configs lazily: root index -> pattern meta -> individual playlists.

## Validation

```bash
# Local (requires uv)
schema/scripts/validate.sh patterns/meta.json
schema/scripts/validate.sh patterns/coten_radio/playlists/regular.json

# CI runs audiflow-editor validate on PRs (see .github/workflows/validate.yml)
```

## CI pipelines

- **validate.yml** -- On PR to env branches: downloads `audiflow-editor` binary, validates all JSON in `patterns/`
- **deploy-pages.yml** -- On merge to env branches: bumps `dataVersion`, deploys `patterns/` to the correct path on `gh-pages`

## Ecosystem

| Repo | Role |
|------|------|
| [audiflow](https://github.com/audiflow/audiflow) | Flutter mobile app (consumes configs) |
| [audiflow-smartplaylist-editor](https://github.com/audiflow/audiflow-smartplaylist-editor) | Web editor (authors configs, owns schema) |
| **audiflow-smartplaylist** (this repo) | Config data + deployment |

Schema SSoT: `audiflow-smartplaylist-editor/crates/sp_core/assets/*.schema.json`

## Documentation

- [docs/overview.md](docs/overview.md) -- Purpose and concepts
- [docs/architecture/system-overview.md](docs/architecture/system-overview.md) -- Data flow and design constraints
- [docs/specs/file-structure.md](docs/specs/file-structure.md) -- Three-level JSON hierarchy spec
- [docs/development/change-workflow.md](docs/development/change-workflow.md) -- How to add or modify patterns

## Contributing

Contributions are welcome, especially new playlist data! Please read our
[Contributing Guide](CONTRIBUTING.md) before submitting a pull request.
All contributors must sign the [Contributor License Agreement](CLA.md).

## License

Playlist data in this repository is licensed under
[Creative Commons Attribution-ShareAlike 4.0 International](LICENSE).
