# Info.plist and Entitlements

When you enable native features, iOS requires matching privacy strings and entitlements.

## Required in most apps

`WKAppBoundDomains` must contain your in-app and auth origins.

## Privacy descriptions

Add these keys in `Info.plist` when feature usage requires them:

| Capability | Key |
| --- | --- |
| Camera | `NSCameraUsageDescription` |
| Microphone | `NSMicrophoneUsageDescription` |
| Location | `NSLocationWhenInUseUsageDescription` |
| Biometrics | `NSFaceIDUsageDescription` |
| HealthKit read/write | `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` |

## Push requirements

For push notifications, ensure:

- Entitlement: `aps-environment`
- Background modes include `remote-notification`

## HealthKit requirements

If `features.healthkit = true`, ensure HealthKit entitlements are enabled in `PWAKit.entitlements` and App ID capabilities.

## Quick verification

```bash
# Validate build/sign setup
codesign -dvvv /path/to/PWAKit.app

# Inspect entitlements in built app
codesign -d --entitlements :- /path/to/PWAKit.app
```

If the app crashes immediately when accessing sensors or biometrics, missing Info.plist usage keys are the first thing to check.
