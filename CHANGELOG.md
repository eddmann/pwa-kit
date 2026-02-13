# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-02-13

### Fixed

- Fix crash when running `init` with a target directory that doesn't exist yet

## [0.1.1] - 2026-02-13

### Fixed

- Extract template directly into the user-specified directory instead of nesting inside a `kit/` subdirectory
- Align ASCII box art in the interactive setup wizard so borders render consistently

### Changed

- Replace GitHub Packages install instructions with npm badges and public registry links

## [0.1.0] - 2026-02-13

Initial release — wrap any Progressive Web App in a native iOS shell with a JavaScript-to-native bridge. Includes a TypeScript SDK, a CLI for project setup and config syncing, and built-in modules for haptics, biometrics, notifications, secure storage, health data, and more.

[0.1.2]: https://github.com/eddmann/pwa-kit/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/eddmann/pwa-kit/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/eddmann/pwa-kit/releases/tag/v0.1.0
