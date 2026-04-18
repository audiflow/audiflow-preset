# audiflow-smartplaylist

Curated smart playlist configurations for the [audiflow](https://github.com/audiflow/audiflow) podcast app. Each configuration tells the app how to group, filter, sort, and display episodes for a specific podcast.

Configs are JSON files deployed to GitHub Pages as static assets. The app fetches them at runtime to power the smart playlist feature.

## How it works

```
You (editor)  -->  edit JSON configs locally
                   |
                   v
               git commit & push
                   |
                   v
               open Pull Request
                   |
                   v
            CI validates configs  -->  merge
                   |
                   v
            CI bumps dataVersion, deploys to GitHub Pages
                   |
                   v
            audiflow app fetches updated configs
```

## Getting started

### Prerequisites

- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/) (`gh`) -- used by the validation script to download the editor binary

### Setup

1. Clone the repo:

```bash
git clone https://github.com/audiflow/audiflow-smartplaylist.git
cd audiflow-smartplaylist
```

2. Check out the environment branch you want to work on:

```bash
git checkout dev/v4    # development
# git checkout stg/v4  # staging
# git checkout prod/v4 # production
```

You can now edit the JSON files in `patterns/` with any editor and validate with `schema/scripts/validate.sh`.

### Using the web editor (optional)

For a visual editing experience with live preview and RSS feed fetching, run:

```bash
./editor.sh
```

This automatically downloads the correct [audiflow-smartplaylist-editor](https://github.com/audiflow/audiflow-smartplaylist-editor) binary (matched to the schema version) and starts the web UI. Open `http://localhost:8080` in your browser.

You can pass extra flags to the editor:

```bash
./editor.sh --port 3000
```

For alternative setups, see the [editor repository](https://github.com/audiflow/audiflow-smartplaylist-editor) (build from source, Docker).

### Using AI coding assistants (optional)

This repo includes an `audiflow-playlist` skill that guides AI assistants through the full pattern creation workflow: searching for podcast feeds, analyzing RSS title patterns, writing JSON configs, and validating. Prerequisite: the helper scripts require Python 3.9+ and the `defusedxml` package (`pip install defusedxml`).

| Tool | Invocation |
|------|------------|
| [Claude Code](https://claude.ai/claude-code) | `/audiflow-playlist create a pattern for <podcast name>` |
| [Codex CLI](https://github.com/openai/codex) | Auto-discovered from `.agents/skills/` |
| [Cursor](https://cursor.com/) | Auto-discovered from `.cursor/skills/` |

All three platforms share the same skill source via symlinks. The skill handles feed lookup, resolver selection, JSON authoring, and browser preview with `./editor.sh`.

## File structure

Configs use a three-level hierarchy for efficient lazy loading:

```
patterns/
  meta.json                          # Root index (discovery)
  {patternId}/
    meta.json                        # Pattern metadata (feed matching, playlist list)
    playlists/
      {playlistId}.json              # Playlist definition (grouping rules)
```

| Level | File | Purpose |
|-------|------|---------|
| Root | `patterns/meta.json` | Lists all patterns with summary info. The app fetches this first. |
| Pattern | `{patternId}/meta.json` | Links a podcast (by feed URL or GUID) to its playlists. |
| Playlist | `playlists/{playlistId}.json` | Defines how episodes are grouped, filtered, sorted, and displayed. |

### Resolver types

Each playlist uses a **resolver type** that determines the grouping algorithm:

| Resolver | Groups episodes by | Example use case |
|----------|-------------------|------------------|
| `seasonNumber` | Season number (from RSS metadata or title parsing) | Numbered series like "Season 1", "Season 2" |
| `year` | Publication year | Annual archives |
| `titleDiscovery` | Recurring patterns found in episode titles | Auto-detected topic clusters |
| `titleClassifier` | Regex rules you define in a `groups` array | Manual categorization (e.g., "Main", "Bonus", "Guest") |

### Presentation modes

| Mode | Behavior |
|------|----------|
| `separate` | Each group becomes its own playlist, selectable via dropdown |
| `combined` | All groups shown as cards within a single playlist view |

## Contributing a playlist

### 1. Fork and clone

Fork this repo on GitHub, then clone your fork:

```bash
git clone https://github.com/YOUR_USERNAME/audiflow-smartplaylist.git
```

### 2. Create a branch

```bash
cd audiflow-smartplaylist
git checkout dev/v4
git checkout -b feat/add-my-podcast
```

### 3. Edit with the editor

Set up and start the editor as described in [Getting started](#getting-started). The editor provides:

- A browser UI for creating and editing playlist configs
- Live preview of how episodes will be grouped
- RSS feed fetching with caching
- JSON schema validation on save

### 4. Validate locally

The editor validates on save. You can also validate from the command line (requires [GitHub CLI](https://cli.github.com/)):

```bash
schema/scripts/validate.sh
```

This downloads the `audiflow-editor` binary matching the schema version in `schema/VERSION` (cached in `.cache/bin/`) and runs validation against `patterns/`.

### 5. Commit and open a PR

```bash
git add patterns/
git commit -m "feat: add playlist config for My Podcast"
git push -u origin feat/add-my-podcast
```

Open a pull request targeting the `dev/v4` branch. CI will validate your configs automatically.

**Important:**
- Do NOT manually edit `dataVersion` fields -- CI bumps them on merge.
- Make sure file/directory names match the `id` fields inside the JSON.
- Pattern IDs are derived from `md5(podcastGuid)` or `md5(feedUrls[0])`, truncated to 12 hex characters.

### Branch flow

Changes promote through environments:

```
dev/v4  -->  stg/v4  -->  prod/v4
```

Each merge triggers CI deployment to the corresponding GitHub Pages path.

## Validation

Both CI and local validation use the [audiflow-smartplaylist-editor](https://github.com/audiflow/audiflow-smartplaylist-editor) binary, version-matched via `schema/VERSION`. The editor binary has JSON schemas embedded at compile time, so the binary version is the single source of truth for validation.

| Schema version | Editor binary | Branch examples |
|----------------|---------------|-----------------|
| v4 | `audiflow-editor` release `v4` | `dev/v4`, `stg/v4`, `prod/v4` |
| v2 | `audiflow-editor` release `v2` | `dev/v2`, `stg/v2`, `prod/v2` |

- **CI**: parses the version from the target branch name and downloads the matching binary.
- **Local**: `schema/scripts/validate.sh` reads `schema/VERSION` and downloads the matching binary.

## Ecosystem

| Repository | Role | License |
|------------|------|---------|
| [audiflow](https://github.com/audiflow/audiflow) | Flutter mobile app | AGPL-3.0-or-later |
| [audiflow-smartplaylist](https://github.com/audiflow/audiflow-smartplaylist) | Playlist config data (this repo) | CC BY-SA 4.0 |
| [audiflow-smartplaylist-editor](https://github.com/audiflow/audiflow-smartplaylist-editor) | Web editor for configs | AGPL-3.0-or-later |

## Contributing

Contributions are welcome! Please read the [Contributing Guide](https://github.com/audiflow/audiflow-smartplaylist-editor/blob/main/CONTRIBUTING.md) before submitting a pull request. All contributors must sign the [Contributor License Agreement](https://github.com/audiflow/audiflow-smartplaylist-editor/blob/main/CLA.md).

## License

This project is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
