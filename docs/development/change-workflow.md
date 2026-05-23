# Change workflow

## Branches

- Edit on `develop` (current schema major, dev environment).
- Promote to `main` via PR (= prod environment).
- Old majors are tag-only; see hotfix section below.

## Adding a new preset

1. Check out `develop`: `git checkout develop && git pull`.
2. Create directory: `presets/{presetId}/`.
3. Create `presets/{presetId}/meta.json` (required: `dataVersion`, `id`, `feedUrls`, `playlists`).
4. Create `presets/{presetId}/playlists/{playlistId}.json` for each playlist.
5. Add a `PresetSummary` entry to `presets/meta.json:.presets` (matching `id`, `dataVersion`, `displayName`, `feedUrlHint`, `playlistCount`).
6. Validate locally: `schema/scripts/validate.sh presets/**/*.json`.
7. Push (or open PR if `develop` is protected). CI runs `validate.yml`, then `bump-versions.yml` cuts a `dev/v{M}.{m}` tag and deploys.

## Modifying an existing preset

1. Check out the relevant working branch (`develop` for current major; a hotfix branch off an old tag for old majors).
2. Edit JSON under `presets/{presetId}/`.
3. Do NOT manually bump `dataVersion` -- CI handles it.
4. Validate locally.
5. Push or open PR.

## Adding a playlist to an existing preset

1. Create `presets/{presetId}/playlists/{newPlaylistId}.json`.
2. Add `{newPlaylistId}` to `presets/{presetId}/meta.json:.playlists`.
3. Update `playlistCount` in `presets/meta.json` for that preset.
4. Validate locally.

## Promoting dev to prod

```
develop -> PR -> main
```

The merge commit on `main` is auto-tagged `prod/v{M}.{m}` and deployed.

## Hotfix on an old schema major

1. List tags for the target major: `git tag -l 'prod/v6.*'`.
2. Check out the latest one: `git checkout prod/v6.42`.
3. Branch: `git checkout -b hotfix/v6-fix-X`.
4. Apply fix; bump `dataVersion` manually (no CI on hotfix branches): `jq '.dataVersion += 1' presets/meta.json | sponge presets/meta.json` (and update affected per-preset `dataVersion`s if you touched them).
5. Commit; tag with the next free minor: `git tag prod/v6.43`.
6. Push the tag (not the branch): `git pull --tags && git push origin prod/v6.43`. Push fails if `prod/v6.43` already exists -- re-fetch and pick a higher minor.

## Schema major bump

See `docs/development/version-branch-rollout.md`.

## CI behavior

- **PR to `main` or `develop`** (`validate.yml`): downloads `audiflow-editor` matching `presets/meta.json:.schemaVersion` on the PR head, runs `validate`.
- **Push to `main` or `develop`** (`bump-versions.yml`): bumps `dataVersion`, commits, tags `{env}/v{M}.{d}`, pushes tag.
- **Push of any `prod/v*.*` or `dev/v*.*` tag** (`deploy-pages.yml`): rebuilds `gh-pages` from all matching tags (highest minor per env+major wins).
