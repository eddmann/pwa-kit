# CLI Overview

`@pwa-kit/cli` has two commands:

- `init`: create/configure a PWAKit project
- `sync`: apply config into native project files

## Install and run

Recommended (no global install):

```bash
npx @pwa-kit/cli init my-pwa-ios
cd my-pwa-ios && npx @pwa-kit/cli sync
```

Optional global install:

```bash
npm install -g @pwa-kit/cli
pwa-kit init
pwa-kit sync
```

## No-clone workflow

You do not need to clone `eddmann/pwa-kit` to build an app.

If `init` does not find `PWAKitApp.xcodeproj`, it downloads the latest template release, extracts it, writes config, and runs sync.

## Command behavior summary

- `init`:
  - interactive when `--url` is omitted in a TTY
  - non-interactive when `--url` is provided
  - validates URL/bundle/color/orientation/display inputs
  - fetches web manifest when available (name/colors/orientation/display/icon)
  - runs sync automatically
- `sync`:
  - requires project + config file
  - supports `apply`, `--dry-run`, and `--validate`

## Read next

- Detailed setup flow: [init Command](/cli/init)
- Sync behavior and validation: [sync Command](/cli/sync)
- Full flag matrix and examples: [CLI Reference](/cli/reference)
