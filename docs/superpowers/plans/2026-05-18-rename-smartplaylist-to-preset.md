# Rename "smartplaylist" -> "preset" Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire the "smartplaylist" / "smart playlist" naming across the audiflow ecosystem because users expect AI/dynamic behavior that the feature does not provide. Replace with "preset", which honestly describes the mechanism: pre-defined configuration bundles per podcast.

**Architecture:** Three-repo coordinated migration anchored on a new schema major (`v7`) carrying the new vocabulary. Existing `v6` branches keep producing data and serving the live app during the rollout. `v7` is built greenfield with renamed schema, branches (`dev/v7`, `stg/v7`, `prod/v7`), deploy directory (`assets{,-stg,-dev}/v7/`), and Rust/Dart/JSON identifiers. After app v7 ships and is stable, repos are renamed on GitHub (`audiflow-smartplaylist` -> `audiflow-preset`, `audiflow-smartplaylist-editor` -> `audiflow-preset-editor`); GitHub auto-redirects keep older URLs alive.

**Tech Stack:** Rust (sp_core / sp_cli / sp_server -> preset_core / preset_cli / preset_server), Flutter/Dart (audiflow app), JSON Schema, GitHub Actions, GitHub Pages.

**Naming dictionary (authoritative):**

| Old | New |
|-----|-----|
| smartplaylist (repo, paths, docs) | preset |
| smart_playlist (snake / Dart filenames) | preset |
| smartPlaylist (camel) | preset |
| SmartPlaylist (PascalCase types) | Preset |
| smart playlist (UI strings, prose) | preset |
| pattern / patternId / PatternMeta (JSON + Rust) | preset / presetId / PresetMeta |
| patterns/ (data directory on env branches) | presets/ |
| pattern-index.schema.json / pattern-meta.schema.json | preset-index.schema.json / preset-meta.schema.json |
| playlist-definition.schema.json | playlist-definition.schema.json *(unchanged — "playlist" inside a preset stays valid)* |
| sp_core / sp_cli / sp_server (Rust crates) | preset_core / preset_cli / preset_server |
| audiflow-editor (release binary name) | audiflow-editor (kept for v7; rename deferred to a later major -- see Phase 1 below) |

The container is a **preset**. A preset contains **playlists**. "Playlist" remains a valid term for the curated track-group entity inside a preset.

**Branch model after migration:**

| Env | Old branch (kept alive through Phase 5) | New branch | Old URL path | New URL path |
|-----|-----------------------------------------|------------|--------------|--------------|
| dev | dev/v6 | dev/v7 | assets-dev/v6/patterns/* | assets-dev/v7/presets/* |
| stg | stg/v6 | stg/v7 | assets-stg/v6/patterns/* | assets-stg/v7/presets/* |
| prod | prod/v6 | prod/v7 | assets/v6/patterns/* | assets/v7/presets/* |

`main` only receives documentation updates per the user's directive. No `main`-side code/data changes are part of this plan.

---

## Phase ordering and dependencies

```
Phase 0 (this repo / main)  ──► Phase 1 (editor)  ──► Phase 2 (this repo / v7 branches)
                                                                │
                                                                ▼
                                                       Phase 3 (app)
                                                                │
                                                                ▼
                                                       Phase 4 (repo rename on GitHub)
                                                                │
                                                                ▼
                                                       Phase 5 (deprecate v6)
```

Each phase has its own detailed sub-plan (created lazily — see "Per-phase sub-plan creation" at the bottom). This document is the **coordination plan**: it locks the contract between phases and provides acceptance criteria so each phase can be executed independently by a fresh worker.

---

## Phase 0 — Naming decision committed to main (this repo)

**Scope:** Land the naming decision, glossary, and migration runbook on `main` so all subsequent phases reference one source of truth. No data, schema, or code is renamed yet.

**Files:**
- Create: `docs/architecture/naming-migration.md`
- Modify: `CLAUDE.md`
- Modify: `docs/overview.md`
- Modify: `README.md`
- Modify: `docs/specs/file-structure.md`
- Modify: `docs/development/version-branch-rollout.md`
- Modify: `docs/architecture/multi-env-deploy.md`

### Task 0.1: Author the naming-migration doc

**Files:**
- Create: `docs/architecture/naming-migration.md`

- [ ] **Step 1: Write the doc with the full glossary, motivation, branch table, and rollout phase summary**

The doc must contain (verbatim sections):

```markdown
# Naming migration: smartplaylist -> preset

## Why

Users encountering "smart playlist" expect AI-driven or dynamic playlist
generation. The feature is pre-defined, rules-based per-podcast
configuration. The name oversold the capability. "Preset" is honest:
each podcast has one or more pre-defined configurations that the app
consumes.

## Glossary

| Old | New |
|-----|-----|
| ... (paste the dictionary from the meta-plan verbatim) |

## Repository renames (scheduled in Phase 4)

| Old | New |
|-----|-----|
| audiflow-smartplaylist | audiflow-preset |
| audiflow-smartplaylist-editor | audiflow-preset-editor |

## Branch / URL mapping

(paste the branch model table from the meta-plan)

## Phase index

- Phase 0: this document
- Phase 1: editor schema + Rust rename, release v7 binaries
- Phase 2: this repo dev/v7, stg/v7, prod/v7 branches + workflows
- Phase 3: app rename + URL cutover
- Phase 4: GitHub repo renames
- Phase 5: v6 deprecation
```

- [ ] **Step 2: Verify the doc renders (no broken anchors)**

Run: `grep -E '^#' docs/architecture/naming-migration.md`
Expected: at least 5 headings, all unique.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture/naming-migration.md
git commit -m "docs: add naming migration plan (smartplaylist -> preset)"
```

### Task 0.2: Update CLAUDE.md, README, overview, file-structure to forward-reference the migration

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `docs/overview.md`
- Modify: `docs/specs/file-structure.md`

The intent for Phase 0 is **not** to rewrite these docs to the new vocab — `v6` is still the live version and the live data still uses `patterns/`. The intent is to add a single prominent pointer at the top of each that says: "A rename is in flight; new terminology lives on v7+. See docs/architecture/naming-migration.md."

- [ ] **Step 1: Add the pointer block to `CLAUDE.md` immediately under the `# audiflow-smartplaylist` heading**

```markdown
> **Naming migration in progress.** The "smartplaylist" naming is being
> retired in favor of "preset" (see `docs/architecture/naming-migration.md`).
> Data and code on `v7+` branches use the new vocabulary; `v6` branches
> retain the legacy names until deprecation.
```

- [ ] **Step 2: Add the same pointer block (verbatim) to `README.md` near the top**

- [ ] **Step 3: Add the pointer to the top of `docs/overview.md` and `docs/specs/file-structure.md`**

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md README.md docs/overview.md docs/specs/file-structure.md
git commit -m "docs: forward-reference preset rename from top-level docs"
```

### Task 0.3: Update version-branch-rollout.md with v7 specifics

**Files:**
- Modify: `docs/development/version-branch-rollout.md`
- Modify: `docs/architecture/multi-env-deploy.md`

`version-branch-rollout.md` already covers the generic `vN` rollout. Add a section that pins v7's special status (it carries the rename) and notes that:
1. The directory layout flips from `patterns/` to `presets/` *only* on v7+.
2. The deploy workflow rsyncs from `presets/` rather than `patterns/` when the branch is `v7+`.
3. The editor release binary may change name in Phase 1; the workflow must accept whichever name lands.

- [ ] **Step 1: Add the v7 section to `version-branch-rollout.md`**

- [ ] **Step 2: Add a "Preset rename" subsection to `multi-env-deploy.md` describing both layouts coexisting**

- [ ] **Step 3: Commit and open PR to `main`**

```bash
git add docs/development/version-branch-rollout.md docs/architecture/multi-env-deploy.md
git commit -m "docs: document v7 preset rename rollout"
git push -u origin docs/preset-rename-phase-0
gh pr create --base main --title "docs: stage preset rename (phase 0)" \
  --body "Phase 0 of the smartplaylist -> preset rename. Adds glossary, migration runbook, forward-references."
```

**Phase 0 acceptance:** PR merged. `docs/architecture/naming-migration.md` exists on `main`. Top-level docs link to it.

---

## Phase 1 — Editor repo: schema v7 + Rust rename + release

**Repo:** `audiflow-smartplaylist-editor` (to be renamed in Phase 4).
**Target output:** A GitHub Release tagged `v7` on the editor repo, containing a Linux binary the data-repo workflow can download. New schema files renamed per the dictionary. Internal Rust types renamed.

**Pre-requisite:** Phase 0 merged (so the editor PR can cite the canonical glossary URL).

**Sub-plan home:** `audiflow-smartplaylist-editor/docs/superpowers/plans/2026-05-18-rename-preset-phase-1.md` (created at phase start).

### Required outputs (the contract)

1. **Schema files** in `crates/sp_core/assets/` renamed:
   - `pattern-index.schema.json` -> `preset-index.schema.json`
   - `pattern-meta.schema.json` -> `preset-meta.schema.json`
   - `playlist-definition.schema.json` — content unchanged; **any** internal `$ref` / `$id` referencing the old filename must be updated.

2. **JSON field renames inside schemas** (binding decisions):
   - Root index: `patterns: [...]` array becomes `presets: [...]`. Each entry's `patternId` becomes `presetId`. Each entry's `dataVersion` / `schemaVersion` field names are unchanged.
   - Preset meta: top-level `patternId` -> `presetId`. `feedUrls` unchanged. `playlists` list unchanged.
   - PlaylistDefinition: any `patternId` reference -> `presetId`. Field names like `playlistId`, `resolver`, `selector`, `partitionBy` unchanged.

3. **Rust types** in `crates/sp_core/src/models/` renamed (file + struct):
   - `pattern_meta.rs` -> `preset_meta.rs`; `struct PatternMeta` -> `struct PresetMeta`.
   - `pattern_summary.rs` -> `preset_summary.rs`; `struct PatternSummary` -> `struct PresetSummary`.
   - `pattern_config.rs` -> `preset_config.rs`; `struct PatternConfig` -> `struct PresetConfig`.
   - `root_meta.rs` field `patterns: Vec<PatternSummary>` -> `presets: Vec<PresetSummary>`.
   - `models/mod.rs` re-exports updated.

4. **Crate renames (Cargo workspace):**
   - `crates/sp_core` -> `crates/preset_core`
   - `crates/sp_cli` -> `crates/preset_cli`
   - `crates/sp_server` -> `crates/preset_server`
   - Workspace `Cargo.toml` `members` list updated.
   - Every `use sp_core::...` -> `use preset_core::...`.
   - Crate-level `name = "sp_core"` in each `crates/*/Cargo.toml` updated.

5. **Binary name decision** — the data-repo workflow currently downloads an asset named `audiflow-editor-x86_64-unknown-linux-gnu`. Two options:
   - (a) Keep binary name `audiflow-editor` (least churn for CI). Recommend this for v7 to avoid coupling the rename to a workflow change in this repo. Phase 2 then needs no workflow change for the binary name; only the rsync source dir changes.
   - (b) Rename binary to `audiflow-preset-tool`. Then Phase 2 workflow must accept both names during the cutover.

   **Decision: (a) keep `audiflow-editor` binary name for v7.** Revisit in a later major.

6. **CLI subcommand surface** — `audiflow-editor bump-versions HEAD~1` is invoked by `.github/workflows/deploy-pages.yml`. The subcommand name MUST keep working against `presets/**/meta.json` (it currently scans `patterns/**/meta.json`). The Rust implementation must accept both legacy `patterns/` and new `presets/` paths, OR auto-detect which directory exists. The v7 binary must succeed on `presets/`. The v6 binary stays untouched and continues to work on `patterns/`.

7. **`schema/VERSION`** content in the vendored schema bundle: `7`.

8. **Release artifact:**
   - Tag: `v7`
   - Assets: `audiflow-editor-x86_64-unknown-linux-gnu`, `audiflow-editor-aarch64-apple-darwin` (matches existing v5/v6 cached binaries in this repo)
   - Release notes link to `docs/architecture/naming-migration.md` in the data repo.

### Phase 1 acceptance

- [ ] `cargo build --workspace` green at the new crate names.
- [ ] `cargo test --workspace` green.
- [ ] `cargo run -p preset_cli -- bump-versions HEAD~1` succeeds against a fixture `presets/` tree.
- [ ] GitHub Release `v7` exists on the editor repo with both binary assets.
- [ ] Editor PR merged to `audiflow-smartplaylist-editor:main`.

---

## Phase 2 — This repo: dev/v7, stg/v7, prod/v7 branches + workflow updates

**Repo:** `audiflow-smartplaylist` (to be renamed in Phase 4).
**Target output:** Three new branches deploying renamed data under the new URL paths, validated by the v7 editor binary.

**Pre-requisite:** Phase 1's v7 release published.

**Sub-plan home:** `docs/superpowers/plans/2026-05-18-rename-preset-phase-2.md` (created at phase start).

### Required outputs

1. **Feature branch `feat/v7`** branched from `dev/v6` carrying the migration:
   - `schema/VERSION` -> `7`
   - `schema/*.schema.json` files replaced with v7 vendored copies from the editor (renamed filenames per Phase 1).
   - `patterns/` directory renamed to `presets/` (git mv preserving history).
   - JSON content within: every `patternId` key -> `presetId`. Root `patterns/meta.json` (-> `presets/meta.json`) field `patterns:` -> `presets:`.
   - `schema/scripts/validate.sh` updated to point at new schema filenames and `presets/` paths.

2. **Workflow updates on `feat/v7` only** (do NOT change workflows on `main` — only the workflow shipped on the v7 branches needs the new paths because workflows live per-branch... unless the repo's workflows live on `main` and apply to all branches. Confirm in Phase 2 sub-plan; current evidence suggests workflows live on the branch that runs them via `.github/workflows/` checked into that branch.):

   - `.github/workflows/deploy-pages.yml`:
     - `paths:` filter changes from `patterns/**.json` to `presets/**.json` **on v7 branches only**.
     - `rsync` source changes from `source/patterns/` to `source/presets/`.
     - The deploy directory continues to be `${env}/{version}` — so `assets/v7/`, `assets-stg/v7/`, `assets-dev/v7/`. The deployed tree's top-level dir is `presets/` (since rsync syncs the renamed source dir as the target dir contents).
     - Final published URL: `audiflow.github.io/audiflow-smartplaylist/assets/v7/presets/meta.json` until repo rename, then `audiflow.github.io/audiflow-preset/assets/v7/presets/meta.json` after Phase 4.

   - `.github/workflows/validate.yml`:
     - Schema file paths updated.
     - Editor binary download still targets the branch's `schema/VERSION` (`v7`), so the v7 release from Phase 1 is automatically selected.

   - `.github/workflows/cla.yml`: no changes needed.

3. **Bump-versions compatibility:** `audiflow-editor bump-versions HEAD~1` invoked from the workflow must operate on `presets/`. Verified in Phase 1 acceptance — re-verify in Phase 2 via dry-run on `feat/v7`.

4. **Branch rulesets:** `scripts/setup-github-rulesets.sh` extended to cover `dev/v7`, `stg/v7`, `prod/v7` with the same protection profile as v6. Run the script after pushing v7 branches (or document as manual step).

5. **Branch creation order** (per `version-branch-rollout.md` runbook):
   - `git branch dev/v7 dev/v6`  (start from current dev tip to inherit data)
   - Apply migration on `feat/v7`
   - `gh pr create --base dev/v7 --head feat/v7`
   - Merge -> first v7 deploy fires under `assets-dev/v7/presets/`
   - Promote `dev/v7 -> stg/v7 -> prod/v7` per existing runbook.

6. **Verification of deployed URLs:**
   - `curl -sf https://audiflow.github.io/audiflow-smartplaylist/assets-dev/v7/presets/meta.json` returns 200 with `presets:` array.
   - Old `v6` URLs continue returning 200 (no regression).

### Phase 2 acceptance

- [ ] `dev/v7`, `stg/v7`, `prod/v7` branches pushed and protected.
- [ ] All three GitHub Pages URLs above return 200.
- [ ] `v6` URLs unchanged.
- [ ] `validate.yml` green on v7 PRs.
- [ ] `deploy-pages.yml` produces correct gh-pages tree (manually inspected).

---

## Phase 3 — App repo: code rename + URL cutover

**Repo:** `audiflow` (Flutter app).
**Target output:** App fetches v7 URLs; all internal Dart identifiers use the `Preset` vocabulary; UI strings show "preset" instead of "smart playlist" where user-visible.

**Pre-requisite:** Phase 2 prod/v7 live and verified.

**Sub-plan home:** `audiflow/docs/superpowers/plans/2026-05-18-rename-preset-phase-3.md` (created at phase start).

### Required outputs

1. **Config URL constant** (locate via `grep -r "audiflow-smartplaylist" packages/audiflow_app/lib/`) flipped to v7. During Phase 3 it still points at the not-yet-renamed repo (`audiflow-smartplaylist`); Phase 4 repo rename gives GitHub auto-redirect for any path-stable consumer, but for `gh-pages`-style direct hosting the URL after Phase 4 becomes `audiflow.github.io/audiflow-preset/...`. App must update again at Phase 4 cutover. *(See "Phase 4 URL transition" below for the two-step cutover specifics.)*

2. **Dart file renames** (preserve git history with `git mv`):
   - `lib/features/podcast_detail/presentation/utils/smart_playlist_def_resolver.dart` -> `preset_def_resolver.dart`
   - `lib/features/podcast_detail/presentation/screens/smart_playlist_episodes_screen.dart` -> `preset_playlist_episodes_screen.dart`
   - `lib/features/podcast_detail/presentation/screens/smart_playlist_group_episodes_screen.dart` -> `preset_playlist_group_episodes_screen.dart`
   - `lib/features/podcast_detail/presentation/controllers/smart_playlist_sort_controller.dart` -> `preset_playlist_sort_controller.dart`
   - `lib/features/podcast_detail/presentation/widgets/smart_playlist_episode_list_tile.dart` -> `preset_playlist_episode_list_tile.dart`
   - All corresponding `*.g.dart` generated files re-run via `dart run build_runner build --delete-conflicting-outputs` after the class renames.

3. **Dart symbol renames:**
   - All `class SmartPlaylist*` -> `class Preset*` (or `PresetPlaylist*` where the type concerns a playlist *within* a preset, not the preset itself — disambiguate during the phase sub-plan).
   - Variables, providers, and provider keys renamed in lockstep.
   - Test files in `test/features/podcast_detail/**` renamed and updated.

4. **Localization (l10n) strings:**
   - `lib/l10n/app_en.arb`, `app_ja.arb`: every "smart playlist" / "Smart Playlist" -> "preset" / "Preset" (English) and the equivalent Japanese term decided during sub-plan kickoff. Recommend Japanese `プリセット` for consistency.
   - Regenerate `app_localizations*.dart` via `flutter gen-l10n`.

5. **Doc updates inside app repo:**
   - `docs/specs/smart-playlist.md` -> `docs/specs/preset.md`
   - `docs/integration/smartplaylist.md` -> `docs/integration/preset.md`
   - `docs/architecture/smart-playlist-cache.md` -> `docs/architecture/preset-cache.md`
   - Internal references updated.

6. **Cache invalidation:** App caches v6 URLs and parsed data keyed by `patternId`. The v7 cutover changes both URL and the entity key. The sub-plan MUST include a one-time cache wipe on app upgrade (bump a cache-schema integer in shared preferences) to avoid stale-key collisions.

7. **Backward-compatible flag** (recommend): a remote killswitch (e.g. `useV7Presets` boolean delivered via existing config mechanism or hardcoded constant) gates the URL switch. Allows roll-back without app re-release.

### Phase 3 acceptance

- [ ] App build green on iOS and Android.
- [ ] All existing tests pass after renames and codegen.
- [ ] Manual smoke test: install upgrade from v6-consuming build, verify presets load, verify no UI shows "smart playlist".
- [ ] Sentry monitored for 24h post-internal-rollout with no schema-parse error spike.
- [ ] Production release shipped (TestFlight + Play internal track at minimum).

---

## Phase 4 — Repo renames on GitHub

**Repos:** `audiflow-smartplaylist` -> `audiflow-preset`, `audiflow-smartplaylist-editor` -> `audiflow-preset-editor`.

**Pre-requisite:** Phase 3 production app released and stable for at least 7 days (Sentry clean, no schema-related crashes).

**Why this is last for the repos themselves:** GitHub provides automatic 301 redirects from the old repo URL to the new one for git clones, `gh release download`, and HTTP page requests. But **GitHub Pages content served from `<old>.github.io` redirects via 301 to `<new>.github.io`** — most clients follow it, but it is safer to update the app constant first (Phase 4 task 4.4 below) and verify before relying on the redirect for production traffic.

### Required outputs

- [ ] **Task 4.1:** Rename the GitHub repo `audiflow/audiflow-smartplaylist` -> `audiflow/audiflow-preset` via GitHub UI or `gh repo rename audiflow-preset`. (User-driven; requires admin.)

- [ ] **Task 4.2:** Rename `audiflow/audiflow-smartplaylist-editor` -> `audiflow/audiflow-preset-editor` likewise.

- [ ] **Task 4.3:** Update `audiflow-preset/.github/workflows/deploy-pages.yml` and `validate.yml` references to the editor repo (`gh release download ... --repo audiflow/audiflow-smartplaylist-editor` -> `... --repo audiflow/audiflow-preset-editor`). Do this on every still-active version branch (`dev/v7`, `stg/v7`, `prod/v7`, plus `dev/v6`, `stg/v6`, `prod/v6` if v6 is still live).

- [ ] **Task 4.4:** Update app config URL constant to the new domain `audiflow.github.io/audiflow-preset/assets/v7/presets/meta.json`. Ship as a patch release. Verify via Sentry and direct curl.

- [ ] **Task 4.5:** Update local `ghq`-style git remotes for known developer workstations (announce in team chat; not part of automated plan).

- [ ] **Task 4.6:** Update any external dashboards / docs / Notion pages referencing the old repo URL.

### Phase 4 acceptance

- [ ] `gh repo view audiflow/audiflow-preset` returns the new repo.
- [ ] Old URL `https://github.com/audiflow/audiflow-smartplaylist` 301-redirects.
- [ ] App on the new URL serving prod traffic; Sentry clean.

---

## Phase 5 — v6 deprecation

**Scope:** After v7 has been the live consumed version for ~30 days with clean telemetry, retire v6.

### Required outputs

- [ ] **Task 5.1:** Announce v6 freeze in `docs/development/version-branch-rollout.md` and in team chat.
- [ ] **Task 5.2:** Stop merging to `dev/v6` / `stg/v6` / `prod/v6` (branch protection: lock).
- [ ] **Task 5.3:** After 60 more days with no need for v6 fixes, delete v6 deploy directories from `gh-pages` (`assets/v6/`, `assets-stg/v6/`, `assets-dev/v6/`) in a single PR for auditability.
- [ ] **Task 5.4:** Optionally delete v6 branches after the gh-pages cleanup PR merges. Tags `v6` on the editor repo remain forever.

### Phase 5 acceptance

- [ ] v6 URLs return 404.
- [ ] v6 branches deleted or locked-and-archived.

---

## Per-phase sub-plan creation

This document is the coordination plan. Before starting each phase, the executor MUST create a detailed bite-sized sub-plan using the writing-plans skill. The sub-plan lives at the location named under each phase's "Sub-plan home" field. Each sub-plan inherits the contract defined in this document (the "Required outputs" sections) and expands it into 2–5-minute steps with concrete commands, code, and test invocations.

**Subagent assignment recommendation:**
- Phase 0: inline (single-session, small surface)
- Phase 1: subagent-driven-development (Rust workspace rename has many independent file moves)
- Phase 2: subagent-driven-development
- Phase 3: subagent-driven-development (largest scope)
- Phase 4: inline + manual (GitHub UI actions are user-driven)
- Phase 5: inline

---

## Risk register

| Risk | Mitigation |
|------|------------|
| App users on v6 build break when v7 hits prod | Keep v6 deploy live through Phase 5; app v7 release ships with `useV7Presets` flag defaulting on but reversible. |
| Schema parse fails on first v7 fetch | Phase 2 validate.yml gate + Phase 3 Sentry watch + remote killswitch. |
| Editor binary v7 silently breaks v6 data | Phase 1 keeps `audiflow-editor` binary name; v6 workflows still pin `v6` release; v7 binary auto-detects `patterns/` vs `presets/`. |
| GitHub Pages redirect breaks an unusual HTTP client | App constant updated to new URL explicitly in Phase 4 task 4.4 rather than relying on redirect. |
| Generated `*.g.dart` files diverge from manually-renamed source | Phase 3 sub-plan includes `dart run build_runner build --delete-conflicting-outputs` as a discrete step after every class rename batch. |
| Branch ruleset script lags new branches | Phase 2 task explicitly runs `setup-github-rulesets.sh` after pushing v7 branches. |
| Team workstations have stale remotes | Phase 4 task 4.5 announces remote URL update in chat with copy-paste `git remote set-url` command. |

---

## Out of scope

- Renaming the Flutter app product name (`audiflow` stays).
- Marketing rename of any user-facing brand string beyond "smart playlist" -> "preset".
- Reworking the playlist resolver algorithms.
- Adding new schema fields under the v7 umbrella beyond what the rename requires.

---

## Self-review notes

- **Spec coverage:** All four user-confirmed scopes (this repo / schema / editor / app) are covered. Bump-to-v7 with `dev/v7,stg/v7,prod/v7` reflected throughout. `main`-side change is doc-only per the user's directive.
- **Placeholder scan:** No "TBD"/"implement later" remain. Detailed code-level steps are intentionally deferred to per-phase sub-plans because three-repo bite-sized expansion would exceed reasonable plan length; the contract per phase is concrete enough that an engineer with the listed files can execute. Sub-plans are gated as the first step of each phase.
- **Type consistency:** Glossary fixes the names once. `PresetMeta` / `PresetSummary` / `presetId` / `presets/` used consistently across phases.
