# @pwa-kit/cli

CLI for creating and configuring PWAKit iOS apps. Generates `pwa-config.json` from a PWA's web manifest and syncs it to the Xcode project (bundle ID, icons, colors, orientations, entitlements).

## Install

```bash
npm install @pwa-kit/cli
```

Or run directly from the monorepo:

```bash
make cli/deps
make cli/build
node cli/dist/index.js <command>
```

## Commands

### `init`

Create or configure a PWAKit project. Fetches the web manifest to auto-detect app name, colors, orientation, display mode, and icon.

```bash
pwa-kit init [dir] [options]
```

**Interactive mode** (no `--url` flag):

```bash
pwa-kit init
```

**Non-interactive mode:**

```bash
pwa-kit init --url "https://myapp.example.com" --features "haptics,notifications"
```

**Options:**

| Flag                      | Description                                                |
| ------------------------- | ---------------------------------------------------------- |
| `-u, --url <url>`         | Start URL (HTTPS required)                                 |
| `-n, --name <name>`       | App display name (falls back to manifest)                  |
| `-b, --bundle-id <id>`    | Bundle identifier (falls back to reversed domain)          |
| `-a, --allowed <origins>` | Additional allowed origins (comma-separated)               |
| `--auth <origins>`        | Auth origins (comma-separated)                             |
| `--bg-color <hex>`        | Background color (falls back to manifest)                  |
| `--theme-color <hex>`     | Theme/accent color (falls back to manifest)                |
| `--orientation <lock>`    | `any`, `portrait`, or `landscape` (falls back to manifest) |
| `--display <mode>`        | `standalone` or `fullscreen` (falls back to manifest)      |
| `--features <list>`       | Comma-separated enabled features                           |
| `-f, --force`             | Overwrite existing config                                  |

**Available features:** `notifications`, `haptics`, `biometrics`, `secureStorage`, `healthkit`, `iap`, `share`, `print`, `clipboard`

**Example** — configure for the demo deployment with all features:

```bash
pwa-kit init \
  --url "https://pwakit-example.eddmann.workers.dev" \
  --features "notifications,haptics,biometrics,secureStorage,healthkit,iap,share,print,clipboard" \
  --force
```

### `sync`

Sync an existing `pwa-config.json` to the Xcode project. Run this after manually editing the config.

```bash
pwa-kit sync [options]
```

**Options:**

| Flag             | Description                                    |
| ---------------- | ---------------------------------------------- |
| `-n, --dry-run`  | Show what would change without modifying files |
| `-v, --validate` | Validate configuration only                    |

## What sync does

- Sets the bundle identifier in `project.pbxproj`
- Updates `WKAppBoundDomains` in `Info.plist`
- Configures orientation lock
- Validates privacy descriptions for enabled features
- Generates asset catalog color sets (background, accent)
- Resizes and installs the app icon
