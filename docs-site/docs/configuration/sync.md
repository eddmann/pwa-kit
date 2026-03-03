# Syncing Config

Use `sync` after manual changes to `pwa-config.json`.

## What sync does

From CLI sync implementation, it performs:

1. Bundle ID sync in `PWAKitApp.xcodeproj/project.pbxproj`
2. `Info.plist` sync for:
   - `WKAppBoundDomains` from `origins.allowed + origins.auth`
   - orientation keys (`UISupportedInterfaceOrientations` and iPad variant)
   - `CFBundleDisplayName` and `CFBundleName`
3. Color asset sync for launch background and accent color
4. Icon resize sync from `src/PWAKit/Resources/AppIcon-source.png`
5. Privacy validation checks for enabled features

## Modes

### Apply

```bash
npx @pwa-kit/cli sync
```

### Dry-run

```bash
npx @pwa-kit/cli sync --dry-run
```

### Validate-only (CI-friendly)

```bash
npx @pwa-kit/cli sync --validate
```

## Privacy validation rules

When corresponding features are enabled, sync validates these keys:

- `cameraPermission` -> `NSCameraUsageDescription`
- `microphonePermission` -> `NSMicrophoneUsageDescription`
- `locationPermission` -> `NSLocationWhenInUseUsageDescription`
- `biometrics` -> `NSFaceIDUsageDescription`
- `healthkit` -> `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription`
- `notifications` -> `UIBackgroundModes` includes `remote-notification`

## Recommended workflow

1. Edit `src/PWAKit/Resources/pwa-config.json`.
2. Run `npx @pwa-kit/cli sync --validate`.
3. If needed, run `npx @pwa-kit/cli sync`.
4. Build and test in Xcode.
