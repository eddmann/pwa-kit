# Run Your First Build

Use this after `npx @pwa-kit/cli init` has completed.

## Build in Xcode (recommended)

1. Open `PWAKitApp.xcodeproj`.
2. Select `PWAKitApp` scheme.
3. Select an iOS simulator.
4. Press `Cmd+B` to build.
5. Press `Cmd+R` to run.

## Terminal build (optional)

```bash
xcodebuild build \
  -project PWAKitApp.xcodeproj \
  -scheme PWAKitApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Terminal tests (optional)

```bash
xcodebuild test \
  -project PWAKitApp.xcodeproj \
  -scheme PWAKitApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Common first-build failures

- Signing errors: set Team in Xcode > Signing & Capabilities.
- Blank page: update origins and run `npx @pwa-kit/cli sync`.
- Privacy crash: missing `NS*UsageDescription` key in `Info.plist`.
