# audiflow-preset

Preset configuration data for the [audiflow](https://github.com/audiflow) podcast ecosystem. Static JSON files deployed to GitHub Pages and fetched by the app at runtime.

## How it works

```
Editor (local) --> git push --> CI validate & deploy --> GitHub Pages --> App fetches
```

The [audiflow-preset-editor](https://github.com/audiflow/audiflow-preset-editor) generates preset configs locally. Users commit and push to this repo. CI validates the JSON, bumps `dataVersion`, and deploys to GitHub Pages.

## Branch and deployment model

Two long-lived branches:

| Branch | Role |
|--------|------|
| `main` | Promoted/stable. Auto-tagged `prod/v{schemaVersion}.{dataVersion}` on each push. |
| `develop` | Current-major working branch. Auto-tagged `dev/v{schemaVersion}.{dataVersion}` on each push. |

`presets/` and `schema/` live at the repo root on both branches.

Deployment is driven by **tags**, not branches. Each tag push builds a Pages artifact from the winning tags' contents and deploys it via GitHub Actions; the Pages source is set to "GitHub Actions" (no persistent deploy branch). Per `(env, major)`, the highest-minor tag wins:

| Tag pattern | Deploy path | URL |
|-------------|------------|-----|
| `prod/v7.*` (max minor) | `/assets/v7/` | `audiflow.github.io/audiflow-preset/assets/v7/` |
| `dev/v7.*` (max minor) | `/assets-dev/v7/` | `audiflow.github.io/audiflow-preset/assets-dev/v7/` |
| `prod/v8.*` (max minor) | `/assets/v8/` | ... |

Promotion: `develop` -> PR -> `main`. Old-major hotfix: check out an old tag, branch, fix, manually tag the next free minor.

Multiple schema majors are served concurrently as long as their tags exist.

## File structure

```
presets/
  meta.json                    # Root index: schemaVersion, dataVersion, preset list
  {presetId}/
    meta.json                  # Preset metadata: feed URLs, playlist IDs
    playlists/
      {playlistId}.json        # Playlist definition: resolver, grouping, display rules
schema/
  *.schema.json                # Vendored JSON schemas (SSoT is in the editor repo)
  scripts/validate.sh          # Local validation (requires uv)
scripts/ci/                    # Shell helpers used by CI workflows
tests/scripts/                 # Bash test harness for scripts/ci/
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

- **validate.yml** -- On PR to `main`/`develop`: reads `presets/meta.json:.schemaVersion`, downloads the matching `audiflow-editor` release, validates all JSON in `presets/`.
- **bump-versions.yml** -- On push to `main`/`develop`: bumps `dataVersion`, commits as the CI bot, and auto-tags `prod/v{schemaVersion}.{dataVersion}` (from `main`) or `dev/v{...}` (from `develop`).
- **deploy-pages.yml** -- On push of any `prod/v*.*` or `dev/v*.*` tag: enumerates all matching tags, picks the highest-minor per `(env, major)`, assembles a Pages artifact from those tags, and deploys it via `actions/upload-pages-artifact` + `actions/deploy-pages` (Pages source = "GitHub Actions").

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
