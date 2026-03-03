# CLI Reference

This page summarizes command surfaces exactly as implemented in `cli/src`.

## Command tree

```text
pwa-kit
  init [dir] [options]
  sync [--dry-run] [--validate]
```

## `init` validation rules

From CLI source (`utils/validation.ts`):

- URL must start with `https://` and match host/path pattern.
- Bundle ID must match reverse-domain-like pattern.
- Colors must be 6-digit hex (`#RRGGBB`).
- Orientation must be `any|portrait|landscape`.
- Display must be `standalone|fullscreen`.

## `init` manifest behavior

`init` attempts to fetch manifest data in this order:

1. Parse `<link rel="manifest" ...>` from start URL HTML.
2. Fallback paths:
   - `/manifest.json`
   - `/manifest.webmanifest`
   - `/site.webmanifest`

When found, it uses values for:

- `name`/`short_name`
- `background_color`
- `theme_color`
- `orientation`
- `display`
- best icon candidate (prefers largest non-maskable)

## `sync` failure behavior

`sync --validate` throws errors on mismatches, including:

- Bundle ID mismatch
- `WKAppBoundDomains` mismatch
- Orientation mismatch
- Missing privacy keys for enabled features
- Missing `remote-notification` background mode for `notifications`
- Out-of-date icon variants relative to `AppIcon-source.png`

## Practical command snippets

Bootstrap project in a new directory:

```bash
npx @pwa-kit/cli init my-pwa-ios --url "https://app.example.com"
open my-pwa-ios/PWAKitApp.xcodeproj
```

Re-validate after config edits:

```bash
npx @pwa-kit/cli sync --validate
```

Preview changes without writing:

```bash
npx @pwa-kit/cli sync --dry-run
```
