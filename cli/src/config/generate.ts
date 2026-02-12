import fs from 'node:fs';
import path from 'node:path';
import type { DisplayMode, Feature, Orientation } from '../utils/validation.js';
import type { PWAConfig } from './schema.js';

export interface GenerateConfigOptions {
  name: string;
  bundleId: string;
  startUrl: string;
  allowedOrigins: string[];
  authOrigins: string[];
  features: Feature[];
  backgroundColor: string;
  themeColor: string;
  orientation: Orientation;
  displayMode: DisplayMode;
}

export function generateConfig(opts: GenerateConfigOptions): PWAConfig {
  const featureMap = {
    notifications: false,
    haptics: false,
    biometrics: false,
    secureStorage: false,
    healthkit: false,
    iap: false,
    share: false,
    print: false,
    clipboard: false,
  } as Record<Feature, boolean>;

  for (const f of opts.features) {
    featureMap[f] = true;
  }

  return {
    version: 1,
    app: {
      name: opts.name,
      bundleId: opts.bundleId,
      startUrl: opts.startUrl,
    },
    origins: {
      allowed: opts.allowedOrigins,
      auth: opts.authOrigins,
      external: [],
    },
    features: featureMap,
    appearance: {
      displayMode: opts.displayMode,
      pullToRefresh: true,
      adaptiveStyle: true,
      statusBarStyle: 'default',
      orientationLock: opts.orientation,
      backgroundColor: opts.backgroundColor,
      themeColor: opts.themeColor,
    },
    notifications: {
      provider: 'apns',
    },
  };
}

export function writeConfig(config: PWAConfig, outputPath: string): void {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(config, null, 2) + '\n');
}
