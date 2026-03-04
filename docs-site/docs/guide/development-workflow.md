# Development Workflow

This page describes the standard workflow for shipping updates to your wrapped PWA app.

## Core loop

1. Update your web app.
2. Update PWAKit config if needed.
3. Sync native project files.
4. Build and run in Xcode.
5. Validate native bridge features.

## Configuration change flow

```bash
npx @pwa-kit/cli sync
```

If you re-run setup with `npx @pwa-kit/cli init . --force`, sync is already included.

Then in Xcode:

1. Build (`Cmd+B`).
2. Run (`Cmd+R`).
3. Test feature changes.

## Safe validation commands

```bash
npx @pwa-kit/cli sync --validate
npx @pwa-kit/cli sync --dry-run
```

## When to revisit SDK integration

Update your JavaScript integration when you:

- Enable new native feature flags
- Add new native module usage
- Add runtime permission prompts (camera/mic/location/Face ID)

## Recommended release checklist

1. Config is synced (`npx @pwa-kit/cli sync`).
2. App builds and runs in simulator.
3. Permission and native flows work on a physical device.
4. No runtime bridge errors in logs.
