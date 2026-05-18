# Version branch rollout

Operational runbook for landing a new schema major version (e.g. v7 -> v8).
For the architectural model (branch layout, gh-pages topology, lifecycle),
see [../architecture/multi-env-deploy.md](../architecture/multi-env-deploy.md).

## CI contract (summary)

- `.github/workflows/deploy-pages.yml` triggers on push to `{env}/vN` and
  downloads the `audiflow-editor` release tagged `vN` from
  `audiflow-preset-editor`. It runs
  `audiflow-editor bump-versions HEAD~1` and commits
  `chore: bump versions` as `audiflow-ci-bot[bot]`. Manual `dataVersion`
  bumps in `presets/**/meta.json` are not required.
- `.github/workflows/validate.yml` triggers on PRs targeting `{env}/vN`
  and downloads the editor release matching the **base** branch version.

## Preconditions

1. `audiflow-preset-editor` has a `vN` Release with the
   `audiflow-editor-x86_64-unknown-linux-gnu` asset. Without it, both
   `validate` and `deploy-pages` hard-fail at `gh release download`.
2. A feature branch (conventionally `feat/vN`) carries the full migration:
   - `schema/VERSION` set to `N`
   - `schema/*.schema.json` vendored from the editor SSoT
   - All `presets/**` migrated to the new schema

Per [multi-env-deploy.md](../architecture/multi-env-deploy.md), `dev/vN`
is conventionally created from `main` so it inherits current workflows
and tooling. Branching from the prior `dev/v{N-1}` is acceptable when
the feature branch already sits on top of it; rebase onto `main` first
if workflow files have diverged.

## Recommended flow (PR-gated)

```bash
git branch dev/vN main        # or dev/v{N-1} if feat/vN already sits on it
git push -u origin dev/vN
gh pr create --base dev/vN --head feat/vN \
  --title "feat: migrate to vN schema"
```

Why:

- Creating `dev/vN` identical to its parent means the initial push carries
  no new commits and does not trigger `deploy-pages`, so no stale-schema
  data is published under `assets-dev/vN/`.
- The PR runs `validate.yml` with the `vN` editor binary against the new
  schema on `feat/vN` -- this is the real gate on migration correctness.
- Merge triggers `deploy-pages` once; `bump-versions` runs automatically.

## Shortcut flow (no PR review)

```bash
git push origin feat/vN:dev/vN
```

Same end state in one step. Skips the `validate.yml` gate; prefer the PR
flow for major version bumps.

## Anti-patterns

- Do not create a separate "bump-only" commit on `dev/vN` for
  `schema/VERSION` or `dataVersion`. The schema bump belongs on
  `feat/vN`; `dataVersion` is bot-managed.
- Do not create `dev/vN` before the editor `vN` release exists.
- Do not rebase `feat/vN` onto `dev/vN` after the PR is open unless
  necessary -- the merge commit is what triggers the first vN deploy.

## Promotion

After `dev/vN` stabilizes, promote through the standard flow documented
in [multi-env-deploy.md](../architecture/multi-env-deploy.md):

```
dev/vN -> PR -> stg/vN -> PR -> prod/vN
```

The editor `vN` release is reused across all three environments.
