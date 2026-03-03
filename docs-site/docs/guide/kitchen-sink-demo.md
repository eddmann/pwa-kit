# Kitchen Sink Demo

Use the hosted demo URL to generate a PWAKit app and explore the full feature surface quickly.

## Generate the demo app from the hosted URL

```bash
npx @pwa-kit/cli init my-pwakit-kitchen-sink \
  --url "https://pwakit-example.eddmann.workers.dev" \
  --name "PWAKit Kitchen Sink" \
  --bundle-id "com.example.pwakit.kitchensink" \
  --features "notifications,haptics,biometrics,secureStorage,healthkit,iap,share,print,clipboard,cameraPermission,microphonePermission,locationPermission"
open my-pwakit-kitchen-sink/PWAKitApp.xcodeproj
```

Then run the app from Xcode (`Cmd+R`).

You do not need to clone the PWAKit repository for this flow.

## What the generated demo shows

- Runtime and bridge detection
- Push registration and badge flows
- Local notification scheduling/cancel/list
- Haptics and vibration patterns
- Share, clipboard, and print APIs
- Biometrics and secure storage
- StoreKit and HealthKit integration paths
- Camera, microphone, and location permission checks

## Device-only capabilities

- APNs push behavior is limited in Simulator.
- HealthKit requires a physical device.

## Related docs

- [SDK Overview](/sdk/overview)
- [iOS Modules](/sdk/ios-modules)
- [Troubleshooting](/help/troubleshooting)
