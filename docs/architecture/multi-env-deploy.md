# Multi-environment deployment

This repo serves production, staging, and development environments across multiple schema versions from a single GitHub Pages deployment.

## Branch model

`main` holds infrastructure (workflows, docs, schema, CODEOWNERS). Data lives on `{env}/v{N}` branches:

| Branch | Deploy directory | URL path |
|--------|-----------------|----------|
| `prod/v7` | `assets/v7/` | `/assets/v7/` |
| `stg/v7` | `assets-stg/v7/` | `/assets-stg/v7/` |
| `dev/v7` | `assets-dev/v7/` | `/assets-dev/v7/` |

Branch flow per version: `dev/v{N}` -> PR -> `stg/v{N}` -> PR -> `prod/v{N}`

New version branches are created from `main` (to inherit the latest workflows and tooling).

## How it works

A single `gh-pages` branch holds all environments and versions side by side:

```
gh-pages branch:
  assets/v7/       <- from prod/v7
  assets-stg/v7/   <- from stg/v7
  assets-dev/v7/   <- from dev/v7
```

When any env branch receives a push to `presets/`, the deploy workflow:

1. Parses the branch name into env prefix and version (e.g., `prod/v7` -> `assets/v7`)
2. Runs version bump on the source branch
3. Checks out `gh-pages` (or initializes it on first run)
4. Syncs `presets/` into the branch's deploy directory via `rsync --delete`
5. Commits and pushes to `gh-pages`

Each branch has its own concurrency group. Push conflicts are handled by retry-with-rebase -- safe because each branch writes to its own directory.

## Schema version lifecycle

1. Schema v7 is current: `dev/v7`, `stg/v7`, `prod/v7` are active
2. Schema v8 ships: create `dev/v8` from `main`, add presets, promote through stg/prod
3. Bug fix for v7: commit to `dev/v7`, promote through `stg/v7` -> `prod/v7`
4. Both `/assets/v7/` and `/assets/v8/` are served concurrently
5. When v7 is sunset: delete `prod/v7` branch (frozen content remains on `gh-pages` until manually cleaned)

## Branch protection

All `prod/*`, `stg/*`, `dev/*`, and `main` branches are protected via GitHub rulesets:
- No direct push (PR required)
- CODEOWNERS review required
- Status checks must pass (validate workflow)
- No force push or deletion

## GitHub Pages configuration

Pages must be configured to deploy from the `gh-pages` branch at `/` (root). Set in Settings > Pages.
