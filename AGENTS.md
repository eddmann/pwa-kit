# AGENTS.md

## Project Overview

PWAKit wraps Progressive Web Apps in native iOS shells with JavaScript bridge access to native capabilities. Swift 6.0 + SwiftUI for iOS, TypeScript SDK (`@eddmann/pwa-kit-sdk`) for web integration. Xcode project-based build (not SwiftPM).

## Setup

```bash
# Verify prerequisites
./scripts/check-prerequisites.sh

# Install tools (if missing)
brew install swiftformat swiftlint

# Configure PWA (interactive)
make setup

# OR non-interactive
./scripts/configure.sh --name "App Name" --url "https://app.example.com" --bundle-id "com.example.app"

# Open Xcode
make open
# Then Cmd+R to build and run
```

SDK setup (optional):
```bash
cd sdk && npm install
```

## Common Commands

| Task | Command |
|------|---------|
| Build iOS | `make open` then Cmd+R in Xcode |
| Build SDK | `cd sdk && npm run build` |
| Test Swift | Cmd+U in Xcode |
| Test SDK | `cd sdk && npm test` |
| Lint | `make lint` |
| Lint + fix | `make lint-fix` |
| Format | `make format` |
| Format check | `make format-check` |
| Type check SDK | `cd sdk && npm run typecheck` |
| Run example | `make example` |
| Sync config | `./scripts/sync-config.sh` |
| Clean | `make clean` |

## Code Conventions

**Swift:**
- Swift 6.0 with strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- 4-space indentation, 120-char line width
- SwiftFormat handles: imports (alphabetical), trailing commas, self insertion
- SwiftLint enforces: no force unwrapping, documentation on public APIs, complexity limits
- File structure: `src/PWAKit/` (app), `src/PWAKitCore/` (framework)
- Modules in `src/PWAKitCore/Modules/` follow `PWAModule` protocol

**TypeScript (SDK):**
- Strict mode enabled
- Source in `sdk/src/`, output in `sdk/dist/`
- Exports: ESM, CommonJS, browser global, TypeScript declarations

**Naming:**
- Swift: PascalCase types, camelCase functions/properties
- Files match primary type name
- Test files: `*Tests.swift` in `tests/` mirroring source structure

## Tests & CI

**Running tests:**
```bash
# Swift tests - in Xcode
Cmd+U

# SDK tests
cd sdk && npm test
cd sdk && npm run test:watch  # watch mode
```

**CI runs on push/PR to main:**
1. `swift-build` (macOS-14): `swift build && swift test`
2. `lint` (macOS-14): SwiftLint + SwiftFormat --lint
3. `sdk-build` (Ubuntu): `npm ci && npm run typecheck && npm run build && npm test`

**Quality thresholds (SwiftLint):**
- Cyclomatic complexity: warn 15, error 25
- Function body: warn 50, error 100 lines
- File length: warn 500, error 1200 lines

## PR & Workflow Rules

**Commit format:** Conventional Commits
```
<type>(<scope>): <subject>

Types: feat, fix, refactor, docs, chore, ci
Scopes: sdk, core, scripts, config, build, example
```

**Examples:**
```
feat(sdk): add clipboard module support
fix(core): resolve memory leak in WebView container
docs: update configuration guide
```

**Branch:** Trunk-based development on `main`

## Security & Gotchas

**Never commit:**
- `src/PWAKit/Resources/pwa-config.json` - generated config
- `*.key`, `*.pem` - certificates
- `.env*` - environment files
- `credentials.json`, `secrets.json`

**Configuration flow:**
1. Run `make setup` or `./scripts/configure.sh`
2. Generates `pwa-config.json` (gitignored)
3. Run `./scripts/sync-config.sh` to update Info.plist

**Gotchas:**
- All URLs must be HTTPS (validated in setup scripts)
- After changing `pwa-config.json`, run `./scripts/sync-config.sh`
- `WKAppBoundDomains` in Info.plist must match `origins.allowed` + `origins.auth`
- Set Development Team in Xcode before building
- No SwiftPM dependencies - pure Xcode project
- SDK has zero runtime dependencies (dev deps only)

**Secrets handling:**
- Use `SecureStorageModule` (Keychain) for runtime secrets
- No API keys in source code
