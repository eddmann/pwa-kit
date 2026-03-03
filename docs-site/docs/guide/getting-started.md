# Getting Started

Goal: create a working iOS wrapper app for your PWA.

## Prerequisites

- macOS 14+
- Xcode 15+
- Node.js 20+
- Internet connection (for template and manifest fetch)

## 1. Initialize project

```bash
npx @pwa-kit/cli init my-pwa-ios
```

This is the normal user flow. The CLI downloads the template and configures it for your app.

Interactive wizard collects:

- Start URL (must be HTTPS)
- App name
- Bundle ID
- Optional allowed origins and feature toggles

What `init` does (from CLI implementation):

1. Detects an existing `PWAKitApp.xcodeproj`.
2. If not found, downloads latest template release.
3. Fetches your web manifest (if available) for defaults.
4. Writes `src/PWAKit/Resources/pwa-config.json`.
5. Runs sync automatically.

## 2. Open and run in Xcode

```bash
open my-pwa-ios/PWAKitApp.xcodeproj
```

Then:

1. Select a simulator (for example iPhone 16).
2. Press `Cmd+R`.

## 3. Verify bridge connectivity

```ts
import { isNative, platform } from "@pwa-kit/sdk";

if (isNative) {
  const info = await platform.getInfo();
  console.log(info.platform, info.version, info.pwaKitVersion);
}
```

## 4. Update config later

After manual edits to `pwa-config.json`, run:

```bash
npx @pwa-kit/cli sync
```

## Next steps

- CLI details: [CLI Overview](/cli/overview)
- Field-level config docs: [Config Schema](/configuration/config-schema)
- SDK references: [SDK Overview](/sdk/overview)

> Working on PWAKit itself (SDK, CLI, iOS shell)?
> Clone this repository and use the `make` targets in the project root.
