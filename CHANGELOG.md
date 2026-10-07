# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Footnotes (`[^1]`) with back-links.
- Bare URLs and `www.` addresses become links, as on GitHub.

### Changed

- Rendering is 12–15× faster. Markdown is now parsed by cmark-gfm directly, in a single pass, instead of through swift-markdown.
- In loose task lists, the checkbox sits inside the item's paragraph, matching GitHub.

### Fixed

- `data-src` attributes in raw HTML `<img>` tags were treated as the image source.
- Unquoted `src` values in raw HTML `<img>` tags weren't embedded.
- Nested lists in tight list items now start on their own line.

## [1.0.0] - 2026-10-07

### Added

- Quick Look preview extension for Markdown files (`.md`, `.markdown`).
- CommonMark and GitHub Flavored Markdown rendering: tables with column alignment, task lists, strikethrough and autolinks.
- GitHub-style alerts: `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` and `[!CAUTION]`.
- YAML and TOML front matter shown as a block at the top of the preview.
- Local images (relative, absolute, `~/` paths and raw HTML `<img>` tags) embedded in the preview.
- Raw HTML passthrough.
- GitHub-like stylesheet with automatic light and dark mode.
- Host app with a sample rendering and a shortcut to the Quick Look extension settings.

[Unreleased]: https://github.com/mp-consulting/quicklook-md/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/mp-consulting/quicklook-md/releases/tag/v1.0.0
