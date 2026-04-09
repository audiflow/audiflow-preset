# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [v3] - 2026-04-08

### Added

- Pattern 9d1626c9a46b (東京ビジネスハブ) with person and others playlists

## [v3] - 2026-04-04

### Changed

- Migrate pattern IDs to content-hash (SHA-256) identifiers
- Bump schema `$id` URIs from v2 to v3
- Bump `schemaVersion` to 3

## [v2] - 2025-12-22

### Changed

- Simplify titleExtractor pattern and remove episodeList
- Add others playlist and refactor topics in cho_soutaisei_riron
- ~~Add priority 30 to others playlist~~ (priority field removed in v4)
- Remove dead nullSeasonGroupKey from topics
- Wrap regex alternation in ASCII group inside full-width parens

### Fixed

- CLA workflow permissions and repo configuration

### Added

- CLA assistant workflow
- CONTRIBUTING and LICENSE docs

## [v1] - 2025-11-01

### Added

- Initial playlist configuration data
- CI deployment to GitHub Pages
- Schema vendoring for local validation
