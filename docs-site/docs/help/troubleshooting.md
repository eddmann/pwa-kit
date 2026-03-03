# Troubleshooting

Use this page as the first triage path.

## First 60 seconds

```bash
npx @pwa-kit/cli sync --validate
npx @pwa-kit/cli sync
cat src/PWAKit/Resources/pwa-config.json | python3 -m json.tool
```

Then rebuild and run in Xcode.

## App launches but page is blank

Most common cause: domains not synced to `WKAppBoundDomains`.

1. Verify `app.startUrl`, `origins.allowed`, and `origins.auth`.
2. Run `npx @pwa-kit/cli sync`.
3. Rebuild and run.

## JS bridge calls fail

1. Confirm `isNative === true`.
2. Confirm feature is enabled in config.
3. Run `npx @pwa-kit/cli sync` and rebuild.
4. Check simulator/device logs.

## Push notifications do not work

Simulator limitation: remote push behavior is limited.

On physical device, confirm:

- `aps-environment` entitlement present
- `UIBackgroundModes` includes `remote-notification`
- Provisioning/App ID include push capability

## Face ID / camera / microphone crash

Likely missing Info.plist privacy key (`NS*UsageDescription`).

## HealthKit unavailable

- Must run on physical device
- `features.healthkit` must be true
- HealthKit entitlement must be enabled
- Health usage descriptions must exist in `Info.plist`

## Useful diagnostics

```bash
# simulator logs
xcrun simctl spawn booted log stream --predicate 'process == "PWAKit"'

# terminal build
xcodebuild build -project PWAKitApp.xcodeproj -scheme PWAKitApp -destination 'platform=iOS Simulator,name=iPhone 16'
```
