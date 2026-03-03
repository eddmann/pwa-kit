# Install Requirements

Use this page when setting up a machine to build PWAKit-based iOS apps.

## Required software

| Tool | Minimum | Notes |
| --- | --- | --- |
| macOS | 14 | Needed for iOS simulator and Xcode |
| Xcode | 15 | Includes Swift toolchain and simulator runtimes |
| Node.js | 20 | Required for `npx @pwa-kit/cli` |
| npm | 10+ | Comes with Node 20 |
| Internet | - | Needed for template and manifest fetch during `init` |

## Verify environment

```bash
xcodebuild -version
node --version
npm --version
```

## CLI usage choices

Recommended (no install):

```bash
npx @pwa-kit/cli init my-pwa-ios
```

Optional global install:

```bash
npm install -g @pwa-kit/cli
pwa-kit init
```

## Common setup issues

- `xcodebuild` not found: install Xcode and command line tools.
- `npx @pwa-kit/cli ...` fails: check Node/npm version and network access.
- Template download fails: retry with stable internet; optionally pin `--template-version`.
