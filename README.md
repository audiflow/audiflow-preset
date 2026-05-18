# audiflow-preset

Preset configuration data for the [audiflow](https://github.com/audiflow) podcast ecosystem. Static JSON files deployed to GitHub Pages and fetched by the app at runtime.

## How it works

```
Editor (local) --> git push --> CI validate & deploy --> GitHub Pages --> App fetches
```

The [audiflow-preset-editor](https://github.com/audiflow/audiflow-preset-editor) generates preset configs locally. Users commit and push to this repo. CI validates the JSON, bumps `dataVersion`, and deploys to GitHub Pages.

## Branch and deployment model

`main` holds infrastructure only (workflows, docs, scripts). Data lives on environment/version branches:

| Branch | Deploy path | URL |
|--------|------------|-----|
| `prod/v7` | `/assets/v7/` | `audiflow.github.io/audiflow-preset/assets/v7/` |
| `stg/v7` | `/assets-stg/v7/` | `audiflow.github.io/audiflow-preset/assets-stg/v7/` |
| `dev/v7` | `/assets-dev/v7/` | `audiflow.github.io/audiflow-preset/assets-dev/v7/` |

Promotion flow: `dev/v{N}` -> PR -> `stg/v{N}` -> PR -> `prod/v{N}`

Multiple schema versions can be served concurrently.

## File structure (on data branches)

```
presets/
  meta.json                    # Root index: dataVersion, schemaVersion, preset list
  {presetId}/
    meta.json                  # Preset metadata: feed URLs, playlist IDs
    playlists/
      {playlistId}.json        # Playlist definition: resolver, grouping, display rules
schema/
  *.schema.json                # Vendored JSON schemas (SSoT is in the editor repo)
  scripts/validate.sh          # Local validation (requires uv)
```

The app loads configs lazily: root index -> preset meta -> individual playlists.

## Validation

```bash
# Local (requires uv)
schema/scripts/validate.sh presets/meta.json
schema/scripts/validate.sh presets/coten_radio/playlists/regular.json

# CI runs audiflow-editor validate on PRs (see .github/workflows/validate.yml)
```

## CI pipelines

- **validate.yml** -- On PR to env branches: downloads `audiflow-editor` binary, validates all JSON in `presets/`
- **deploy-pages.yml** -- On merge to env branches: bumps `dataVersion`, deploys `presets/` to the correct path on `gh-pages`

## Ecosystem

| Repo | Role |
|------|------|
| [audiflow](https://github.com/audiflow/audiflow) | Flutter mobile app (consumes configs) |
| [audiflow-preset-editor](https://github.com/audiflow/audiflow-preset-editor) | Web editor (authors configs, owns schema) |
| **audiflow-preset** (this repo) | Config data + deployment |

Schema SSoT: `audiflow-preset-editor/crates/preset_core/assets/*.schema.json`

## Documentation

- [docs/overview.md](docs/overview.md) -- Purpose and concepts
- [docs/architecture/system-overview.md](docs/architecture/system-overview.md) -- Data flow and design constraints
- [docs/specs/file-structure.md](docs/specs/file-structure.md) -- Three-level JSON hierarchy spec
- [docs/development/change-workflow.md](docs/development/change-workflow.md) -- How to add or modify presets

## Contributing

Contributions are welcome, especially new preset data! Please read our
[Contributing Guide](CONTRIBUTING.md) before submitting a pull request.
All contributors must sign the [Contributor License Agreement](CLA.md).

## License

Preset data in this repository is licensed under
[Creative Commons Attribution-ShareAlike 4.0 International](LICENSE).
