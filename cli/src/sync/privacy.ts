import fs from 'node:fs';
import plist from 'plist';
import { logger } from '../utils/logger.js';
import type { PWAConfig } from '../config/schema.js';

const REQUIRED_DESCRIPTIONS: Record<string, string | string[]> = {
  cameraPermission: 'NSCameraUsageDescription',
  locationPermission: 'NSLocationWhenInUseUsageDescription',
  biometrics: 'NSFaceIDUsageDescription',
  healthkit: ['NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription'],
};

export function validatePrivacy(
  plistPath: string,
  features: PWAConfig['features'],
): string[] {
  logger.step('Validating privacy descriptions...');

  const errors: string[] = [];

  if (!fs.existsSync(plistPath)) {
    logger.warn('Info.plist not found, skipping privacy validation');
    return errors;
  }

  const raw = fs.readFileSync(plistPath, 'utf-8');
  const data = plist.parse(raw) as Record<string, unknown>;

  for (const [feature, plistKey] of Object.entries(REQUIRED_DESCRIPTIONS)) {
    if (!(features as Record<string, boolean>)[feature]) continue;

    const keys = Array.isArray(plistKey) ? plistKey : [plistKey];
    for (const key of keys) {
      if (!(key in data)) {
        errors.push(`Missing ${key} (required for ${feature})`);
        logger.error(`Missing ${key} (required when features.${feature} is true)`);
      } else {
        logger.success(`${key} present`);
      }
    }
  }

  // Check notifications background mode
  if (features.notifications) {
    const bgModes = (data['UIBackgroundModes'] as string[]) ?? [];
    if (!bgModes.includes('remote-notification')) {
      errors.push("Missing 'remote-notification' in UIBackgroundModes");
      logger.error("Missing 'remote-notification' in UIBackgroundModes (required for notifications)");
    } else {
      logger.success('UIBackgroundModes includes remote-notification');
    }
  }

  return errors;
}
