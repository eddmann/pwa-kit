# PWAKit Configuration Guide

This document explains how to configure PWAKit for your Progressive Web App, including Info.plist requirements, entitlements, and feature flags.

## Configuration Files Overview

| File                  | Purpose                                  | When Updated                      |
| --------------------- | ---------------------------------------- | --------------------------------- |
| `pwa-config.json`     | Source of truth for app configuration    | Edit manually                     |
| `Info.plist`          | iOS app metadata and permissions         | Sync via build script or manually |
| `PWAKit.entitlements` | App capabilities (push, HealthKit, etc.) | Edit for capabilities             |

## pwa-config.json

The primary configuration file located at `kit/src/PWAKit/Resources/pwa-config.json`.

```json
{
  "version": 1,
  "app": {
    "name": "My PWA",
    "bundleId": "com.example.mypwa",
    "startUrl": "https://app.example.com/"
  },
  "origins": {
    "allowed": ["app.example.com"],
    "auth": ["auth.example.com"],
    "external": []
  },
  "features": {
    "notifications": true,
    "haptics": true,
    "biometrics": true,
    "secureStorage": true,
    "healthkit": false,
    "iap": false,
    "share": true,
    "print": true,
    "clipboard": true,
    "cameraPermission": true,
    "microphonePermission": true,
    "locationPermission": true
  },
  "appearance": {
    "displayMode": "standalone",
    "pullToRefresh": false,
    "statusBarStyle": "adaptive",
    "orientationLock": "any",
    "backgroundColor": "#FFFFFF",
    "themeColor": "#007AFF"
  },
  "notifications": {
    "provider": "apns"
  }
}
```

### Origins Configuration

| Field              | Description                                         | Maps To                           |
| ------------------ | --------------------------------------------------- | --------------------------------- |
| `origins.allowed`  | Domains that can load in the WebView                | `WKAppBoundDomains` in Info.plist |
| `origins.auth`     | OAuth/login domains (show toolbar with Done button) | `WKAppBoundDomains` in Info.plist |
| `origins.external` | Domains that open in SFSafariViewController         | N/A                               |

**Important**: The `origins.allowed` and `origins.auth` arrays must be synced to `WKAppBoundDomains` in Info.plist. Run the sync command after changing these values:

```bash
make kit/sync
```

## Info.plist Requirements

The Info.plist file is located at `kit/src/PWAKit/Info.plist`.

### Required for All Apps

These are always required:

```xml
<key>WKAppBoundDomains</key>
<array>
    <string>app.example.com</string>
    <!-- Add all allowed + auth origins here -->
</array>
```

### Conditional Privacy Descriptions

Add these based on which features your PWA uses:

| Feature    | Info.plist Key                                                    | Required When                    |
| ---------- | ----------------------------------------------------------------- | -------------------------------- |
| Camera     | `NSCameraUsageDescription`                                        | PWA uses camera/photo capture    |
| Microphone | `NSMicrophoneUsageDescription`                                    | PWA records audio or video calls |
| Location   | `NSLocationWhenInUseUsageDescription`                             | PWA uses geolocation             |
| Face ID    | `NSFaceIDUsageDescription`                                        | `features.biometrics` is `true`  |
| HealthKit  | `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` | `features.healthkit` is `true`   |

Example privacy descriptions:

```xml
<!-- Camera - for photo/video capture -->
<key>NSCameraUsageDescription</key>
<string>Take photos and videos for your content</string>

<!-- Microphone - for audio recording, video calls -->
<key>NSMicrophoneUsageDescription</key>
<string>Record audio for voice messages</string>

<!-- Location - for geolocation features -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Find nearby locations and provide directions</string>

<!-- Face ID - for biometric authentication -->
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely authenticate</string>

<!-- HealthKit - for health data access -->
<key>NSHealthShareUsageDescription</key>
<string>Read your health data to display activity information</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Save workout data to the Health app</string>
```

### Background Modes

Required for push notifications:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>remote-notification</string>
</array>
```

## Entitlements (PWAKit.entitlements)

The entitlements file is located at `kit/src/PWAKit/PWAKit.entitlements`.

### Complete Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Push Notifications -->
    <key>aps-environment</key>
    <string>development</string>

    <!-- Universal Links -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:YOUR_DOMAIN.com</string>
    </array>

    <!-- HealthKit (if enabled) -->
    <key>com.apple.developer.healthkit</key>
    <true/>
</dict>
</plist>
```

### Push Notifications

Required when `features.notifications` is `true`:

```xml
<key>aps-environment</key>
<string>development</string>  <!-- Use "production" for App Store -->
```

### HealthKit

Required when `features.healthkit` is `true`:

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

### Associated Domains (Universal Links)

Required for universal link support:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:app.example.com</string>
    <string>webcredentials:app.example.com</string>
</array>
```

### App Groups (Optional)

For sharing data between app and extensions:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.example.mypwa</string>
</array>
```

## Feature Flags Reference

| Flag                 | Description                  | Requires                                           |
| -------------------- | ---------------------------- | -------------------------------------------------- |
| `notifications`      | Push notification support    | `aps-environment` entitlement, `UIBackgroundModes` |
| `haptics`            | Haptic feedback              | None                                               |
| `biometrics`         | Face ID / Touch ID           | `NSFaceIDUsageDescription`                         |
| `secureStorage`      | Keychain storage             | None                                               |
| `healthkit`          | HealthKit data access        | HealthKit entitlement, usage descriptions          |
| `iap`                | In-App Purchases             | StoreKit capability                                |
| `share`              | Share sheet                  | None                                               |
| `print`              | AirPrint                     | None                                               |
| `clipboard`          | System clipboard             | None                                               |
| `cameraPermission`   | Camera permission requests   | `NSCameraUsageDescription`                         |
| `microphonePermission` | Microphone permission requests | `NSMicrophoneUsageDescription`                 |
| `locationPermission` | Location permission requests | `NSLocationWhenInUseUsageDescription`              |

## Syncing Configuration

After modifying `pwa-config.json`, run the sync command to update the Xcode project:

```bash
make kit/sync
```

This command:

1. Reads `origins.allowed` and `origins.auth` from pwa-config.json
2. Updates `WKAppBoundDomains` in Info.plist
3. Syncs color assets and app icon
4. Validates that required privacy descriptions exist for enabled features

### Manual Sync

If you prefer manual updates, ensure:

1. **WKAppBoundDomains** contains all domains from `origins.allowed` + `origins.auth`
2. **Privacy descriptions** exist for all features that need them
3. **Entitlements** are configured for capabilities you use

## Common Issues

### "App-bound domain failure"

The domain isn't in `WKAppBoundDomains`. Run `make kit/sync` or manually add it.

### "This app has crashed because it attempted to access privacy-sensitive data"

Missing privacy description in Info.plist. Add the appropriate `NS*UsageDescription` key.

### "Push notifications not working"

1. Check `aps-environment` entitlement is set
2. Ensure `UIBackgroundModes` includes `remote-notification`
3. Verify `features.notifications` is `true` in pwa-config.json

### "HealthKit not available"

1. Add HealthKit entitlement
2. Add both `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`
3. Set `features.healthkit` to `true` in pwa-config.json
