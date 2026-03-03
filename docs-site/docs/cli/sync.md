# `sync` Command

Goal: apply `pwa-config.json` to Xcode project files and validate iOS requirements.

## Usage

```bash
npx @pwa-kit/cli sync [options]
```

## Options

| Flag | Description |
| --- | --- |
| `-n, --dry-run` | Show changes without writing files |
| `-v, --validate` | Validate only, fail if out of sync |

## Mode behavior

### Apply mode (default)

```bash
npx @pwa-kit/cli sync
```

Writes project/plist/assets when needed.

### Dry-run mode

```bash
npx @pwa-kit/cli sync --dry-run
```

Prints what would change.

### Validate mode

```bash
npx @pwa-kit/cli sync --validate
```

Fails with non-zero exit if config and native project differ.

## What sync checks/updates

- `PRODUCT_BUNDLE_IDENTIFIER` in `project.pbxproj`
- `WKAppBoundDomains` in `Info.plist`
- Orientation keys in `Info.plist`
- `CFBundleDisplayName` and `CFBundleName`
- Colorsets from configured colors
- Icon variants from `AppIcon-source.png`
- Privacy keys for enabled features

## Preconditions

- Must run from a directory where project can be detected.
- `src/PWAKit/Resources/pwa-config.json` must exist.

If config is missing, run `npx @pwa-kit/cli init` first.
