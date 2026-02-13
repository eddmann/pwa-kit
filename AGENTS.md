# AGENTS.md

## Project Overview

PWAKit wraps PWAs in native iOS shells with a JS-to-native bridge. Three components: Swift 6.0 + SwiftUI iOS app (`kit/`), TypeScript SDK (`sdk/`), Node.js CLI (`cli/`). Xcode project-based (not SwiftPM). Node 20, npm.

## Common Commands

Run `make` to see all targets.

| Task         | Command                                        |
| ------------ | ---------------------------------------------- |
| Setup        | `make kit/deps cli/deps` then `make kit/setup` |
| Open Xcode   | `make kit/open`, then Cmd+R                    |
| Build iOS    | `make kit/build`                               |
| Kit tests    | `make kit/test`                                |
| Kit lint     | `make kit/lint`                                |
| Kit format   | `make kit/fmt`                                 |
| SDK tests    | `make sdk/test`                                |
| CLI tests    | `make cli/test`                                |
| Sync config  | `make kit/sync`                                |
| All CI gates | `make can-release`                             |
| Set version  | `make version V=0.2.0`                         |

`kit/build` and `kit/test` default to iPhone 16 Simulator. Override with `DESTINATION`:

```bash
make kit/build DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro"
```

## Code Conventions

**Swift:**

- Swift 6.0, strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- 4-space indent, 120-char lines. Config in `kit/.swiftformat` and `kit/.swiftlint.yml`
- All types `Sendable`. Actors for shared mutable state. `@MainActor` for UIKit. Async/await only — no completion handlers
- `kit/src/PWAKit/` (app), `kit/src/PWAKitCore/` (framework)
- Modules in `kit/src/PWAKitCore/Modules/` follow `PWAModule` protocol

**TypeScript:** Strict mode, tsup build. SDK exports ESM + CJS + browser global. Zero runtime deps in SDK.

**Tests:** Swift uses Apple Testing (`@Suite`, `@Test`, `#expect`). TypeScript uses Vitest. Test files: `*Tests.swift` in `kit/tests/`, `*.test.ts` in `sdk/tests/` and `cli/tests/`

## Commits

Conventional Commits: `<type>(<scope>): <subject>`

- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`
- Scopes: `sdk`, `cli`, `core`, `scripts`, `config`, `build`, `example`

## Gotchas

- **Never commit** `pwa-config.json`, `*.key`, `*.pem`, `.env*`, `credentials.json`, `secrets.json`
- After editing `pwa-config.json`, run `make kit/sync` — syncs to pbxproj, Info.plist, colorsets, icons
- `WKAppBoundDomains` in Info.plist must match `origins.allowed` + `origins.auth`
- All URLs must be HTTPS
- No SwiftPM — pure Xcode project
- Use `SecureStorageModule` (Keychain) for runtime secrets, no API keys in source
