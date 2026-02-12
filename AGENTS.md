# AGENTS.md

## Project Overview

PWAKit wraps Progressive Web Apps in native iOS shells with JavaScript bridge access to native capabilities. Swift 6.0 + SwiftUI for iOS, TypeScript SDK (`@eddmann/pwa-kit-sdk`) for web integration. Xcode project-based build (not SwiftPM).

## Setup

```bash
# Install tools (if missing)
brew install swiftformat swiftlint

# Install CLI dependencies
cd cli && npm install && cd ..

# Configure PWA (interactive)
make kit/setup

# OR non-interactive
node cli/dist/index.js init --url "https://app.example.com" --name "App Name" --bundle-id "com.example.app"

# Open Xcode
make kit/open
# Then Cmd+R to build and run
```

SDK setup (optional):

```bash
cd sdk && npm install
```

## Common Commands

Run `make` to see all targets. Key workflows:

| Task        | Command                     |
| ----------- | --------------------------- |
| Setup       | `make kit/setup`            |
| Open Xcode  | `make kit/open`, then Cmd+R |
| Run example | `make example/serve`        |
| Sync config | `make kit/sync`             |
| Kit CI gate | `make kit/can-release`      |
| SDK CI gate | `make sdk/can-release`      |
| CLI CI gate | `make cli/can-release`      |

## Code Conventions

**Swift:**

- Swift 6.0 with strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
- 4-space indentation, 120-char line width
- SwiftFormat handles: imports (alphabetical), trailing commas, self insertion
- SwiftLint enforces: unused declarations/imports, complexity limits, closure/operator formatting
- File structure: `kit/src/PWAKit/` (app), `kit/src/PWAKitCore/` (framework)
- Modules in `kit/src/PWAKitCore/Modules/` follow `PWAModule` protocol

**TypeScript (SDK):**

- Strict mode enabled
- Source in `sdk/src/`, output in `sdk/dist/`
- Exports: ESM, CommonJS, browser global, TypeScript declarations

**Naming:**

- Swift: PascalCase types, camelCase functions/properties
- Files match primary type name
- Test files: `*Tests.swift` in `kit/tests/` mirroring source structure

## Tests & CI

**Running tests:**

```bash
# Swift tests - in Xcode
Cmd+U

# SDK tests
cd sdk && npm test
cd sdk && npm run test:watch  # watch mode
```

**CI runs on push/PR to main — each component has a `can-release` gate:**

- `kit` (macOS): `make kit/can-release` — fmt check, lint, build, test
- `sdk` (Ubuntu): `make sdk/can-release` — build, typecheck, test
- `cli` (Ubuntu): `make cli/can-release` — build, typecheck, test

**Quality thresholds (SwiftLint):**

- Cyclomatic complexity: warn 20, error 120
- Function body: warn 150, error 300 lines
- File length: warn 1500, error 2500 lines

## PR & Workflow Rules

**Commit format:** Conventional Commits

```
<type>(<scope>): <subject>

Types: feat, fix, refactor, docs, chore, ci
Scopes: sdk, cli, core, scripts, config, build, example
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

- `kit/src/PWAKit/Resources/pwa-config.json` - generated config
- `*.key`, `*.pem` - certificates
- `.env*` - environment files
- `credentials.json`, `secrets.json`

**Configuration flow:**

- Run `make kit/setup` (or `node cli/dist/index.js init`)
- Generates `pwa-config.json` (gitignored) + downloads icon
- Automatically syncs to Xcode project (pbxproj, Info.plist, colorsets, icons)
- After manual edits to `pwa-config.json`, run `make kit/sync`

**Gotchas:**

- All URLs must be HTTPS (validated by CLI)
- After changing `pwa-config.json`, run `make kit/sync`
- `WKAppBoundDomains` in Info.plist must match `origins.allowed` + `origins.auth`
- Set Development Team in Xcode before building
- No SwiftPM dependencies - pure Xcode project
- SDK has zero runtime dependencies (dev deps only)

**Secrets handling:**

- Use `SecureStorageModule` (Keychain) for runtime secrets
- No API keys in source code
