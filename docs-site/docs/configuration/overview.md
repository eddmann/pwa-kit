# Configuration Overview

PWAKit uses `pwa-config.json` as the source of truth for app behavior.

## File location

In generated projects:

`src/PWAKit/Resources/pwa-config.json`

## Recommended learning path

1. [Configuration Basics](/configuration/basics)
2. [Full pwa-config.json](/configuration/full-pwa-config)
3. [Origins and URL Rules](/configuration/origins)
4. [Info.plist and Entitlements](/configuration/ios-capabilities)
5. [Syncing Config](/configuration/sync)
6. [Advanced Usage](/configuration/advanced-usage)

## Core rule

After manual config edits, run:

```bash
npx @pwa-kit/cli sync
```
