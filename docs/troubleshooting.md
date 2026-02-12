# Troubleshooting

This document covers common issues and their solutions when developing with PWAKit.

## Build Issues

| Issue                         | Cause                | Solution                                |
| ----------------------------- | -------------------- | --------------------------------------- |
| "No signing identity found"   | Missing code signing | Open in Xcode, enable automatic signing |
| "Swift 6 not available"       | Old Xcode            | Update to Xcode 15.0+                   |
| "Module not found"            | Build cache issue    | Run `make clean` then rebuild in Xcode  |
| "No such module 'PWAKitCore'" | Clean build needed   | Delete DerivedData and rebuild          |

## Simulator Issues

| Issue                 | Cause                      | Solution                                              |
| --------------------- | -------------------------- | ----------------------------------------------------- |
| Simulator won't boot  | Stale state                | `xcrun simctl shutdown all && xcrun simctl erase all` |
| App won't install     | Old build                  | `make clean` and rebuild in Xcode                     |
| Blank screen          | App-bound domains mismatch | Check `WKAppBoundDomains` in Info.plist               |
| Push not working      | Expected                   | Push only works on physical devices                   |
| HealthKit unavailable | Expected                   | HealthKit only works on physical devices              |
| Bridge calls fail     | HTTPS required             | Ensure your PWA uses HTTPS                            |

## Device Issues

| Issue                 | Cause                | Solution                                                |
| --------------------- | -------------------- | ------------------------------------------------------- |
| "Unable to install"   | Provisioning profile | Ensure device is registered in Apple Developer portal   |
| "Untrusted Developer" | First install        | Settings > General > Device Management > Trust          |
| App crashes on launch | Missing capability   | Check entitlements match App ID capabilities            |
| Face ID not working   | Missing description  | Add `NSFaceIDUsageDescription` to Info.plist            |
| Location not working  | Missing description  | Add `NSLocationWhenInUseUsageDescription` to Info.plist |

## Configuration Issues

| Issue                                                                        | Cause                           | Solution                                                    |
| ---------------------------------------------------------------------------- | ------------------------------- | ----------------------------------------------------------- |
| "App-bound domain failure"                                                   | Domain not in WKAppBoundDomains | Run `./scripts/sync-config.sh` or manually add domain       |
| "This app has crashed because it attempted to access privacy-sensitive data" | Missing privacy description     | Add the appropriate `NS*UsageDescription` key to Info.plist |
| "Invalid configuration"                                                      | Malformed JSON                  | Validate with `python3 -m json.tool`                        |
| Origins not working                                                          | Wildcard mismatch               | Check pattern syntax (e.g., `*.example.com`)                |

## Push Notification Issues

| Issue            | Cause                   | Solution                                         |
| ---------------- | ----------------------- | ------------------------------------------------ |
| Push not working | Missing entitlement     | Add `aps-environment` to entitlements            |
| Push not working | Missing background mode | Add `remote-notification` to `UIBackgroundModes` |
| Push not working | Simulator               | Push only works on physical devices              |
| Push not working | Feature disabled        | Set `features.notifications` to `true` in config |

## HealthKit Issues

| Issue                      | Cause               | Solution                                                                      |
| -------------------------- | ------------------- | ----------------------------------------------------------------------------- |
| HealthKit not available    | Simulator           | HealthKit only works on physical devices                                      |
| HealthKit not available    | Missing entitlement | Add HealthKit entitlement to app                                              |
| HealthKit not available    | Feature disabled    | Set `features.healthkit` to `true` in config                                  |
| Authorization denied       | User rejected       | App must handle denial gracefully                                             |
| Missing usage descriptions | App Store rejection | Add both `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` |

## SDK Issues

| Issue                    | Cause                 | Solution                                             |
| ------------------------ | --------------------- | ---------------------------------------------------- |
| `isNative` is false      | Running in browser    | SDK correctly detects non-native environment         |
| `BridgeUnavailableError` | Not in PWAKit app     | Check `isNative` before calling bridge               |
| `BridgeTimeoutError`     | Module not responding | Check if module is registered and feature is enabled |
| Types not found          | Missing build         | Run `npm run build` in sdk/                          |

## Common Fixes

### Clean Build

```bash
# Clean all build artifacts
make clean

# Also clean Xcode's derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/PWAKitApp-*
```

### Check Prerequisites

```bash
./scripts/check-prerequisites.sh
```

### Verify Configuration

```bash
# Check JSON syntax
cat kit/src/PWAKit/Resources/pwa-config.json | python3 -m json.tool

# Check if file exists
ls -la kit/src/PWAKit/Resources/pwa-config.json
```

### View Logs

```bash
# Simulator logs
xcrun simctl spawn booted log stream --predicate 'process == "PWAKit"'

# Device logs (requires Xcode)
# Window > Devices and Simulators > View Device Logs
```

### Check Code Signing

```bash
# Verify app is signed
codesign -dvvv /path/to/PWAKit.app

# View entitlements
codesign -d --entitlements :- /path/to/PWAKit.app
```

### Reset Simulator

```bash
# Shutdown all simulators
xcrun simctl shutdown all

# Erase all simulators
xcrun simctl erase all
```

## Getting Help

If you're still stuck:

1. Check the [GitHub Issues](https://github.com/eddmann/pwa-kit/issues) for similar problems
2. Review the [Architecture](architecture.md) doc to understand how components connect
3. Open a new issue with:
   - PWAKit version
   - Xcode version
   - iOS version
   - Steps to reproduce
   - Error messages/logs
