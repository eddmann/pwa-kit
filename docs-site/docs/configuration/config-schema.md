# Config Schema

This is a compact schema view. For field-by-field detail and complete examples, use [Full pwa-config.json](/configuration/full-pwa-config).

## Top-level

| Field | Required |
| --- | --- |
| `version` | Yes |
| `app` | Yes |
| `origins` | Yes |
| `features` | No |
| `appearance` | No |
| `notifications` | No |

## Quick validation commands

```bash
cat src/PWAKit/Resources/pwa-config.json | python3 -m json.tool
npx @pwa-kit/cli sync --validate
```

## Schema version

- Current: `1`
