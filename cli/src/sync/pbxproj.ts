import fs from 'node:fs';
import { logger } from '../utils/logger.js';

export interface PbxprojSyncResult {
  bundleIdUpdated: boolean;
  displayNameUpdated: boolean;
}

export function syncPbxproj(
  pbxprojPath: string,
  targetBundleId: string,
  targetAppName: string,
  mode: 'apply' | 'dry-run' | 'validate',
): PbxprojSyncResult {
  const result: PbxprojSyncResult = { bundleIdUpdated: false, displayNameUpdated: false };

  if (!fs.existsSync(pbxprojPath)) {
    logger.warn('project.pbxproj not found, skipping');
    return result;
  }

  let content = fs.readFileSync(pbxprojPath, 'utf-8');

  // Sync bundle ID
  if (targetBundleId) {
    const currentIds = content.match(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g) ?? [];
    const uniqueIds = new Set(currentIds.map((m) => m.replace(/PRODUCT_BUNDLE_IDENTIFIER = |;/g, '')));
    const count = currentIds.length;

    if (uniqueIds.size === 1 && uniqueIds.has(targetBundleId)) {
      logger.success(`PRODUCT_BUNDLE_IDENTIFIER is already in sync (${targetBundleId})`);
    } else if (mode === 'dry-run') {
      logger.warn(
        `Would update PRODUCT_BUNDLE_IDENTIFIER: ${[...uniqueIds].join(', ')} → ${targetBundleId} (${count} occurrences)`,
      );
    } else if (mode === 'validate') {
      logger.error(`PRODUCT_BUNDLE_IDENTIFIER mismatch!`);
      logger.detail(`Expected: ${targetBundleId}`);
      logger.detail(`Actual: ${[...uniqueIds].join(', ')}`);
      throw new Error('PRODUCT_BUNDLE_IDENTIFIER not in sync with pwa-config.json');
    } else {
      content = content.replace(
        /PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/g,
        `PRODUCT_BUNDLE_IDENTIFIER = ${targetBundleId};`,
      );
      result.bundleIdUpdated = true;
      logger.success(`Updated PRODUCT_BUNDLE_IDENTIFIER: ${targetBundleId} (${count} occurrences)`);
    }
  }

  // Sync display name
  if (targetAppName) {
    const currentNames = content.match(/INFOPLIST_KEY_CFBundleDisplayName = "([^"]+)"/g) ?? [];
    const uniqueNames = new Set(
      currentNames.map((m) => m.replace(/INFOPLIST_KEY_CFBundleDisplayName = "|"/g, '')),
    );

    if (currentNames.length === 0) {
      logger.warn('INFOPLIST_KEY_CFBundleDisplayName not found in pbxproj, skipping');
    } else if (uniqueNames.size === 1 && uniqueNames.has(targetAppName)) {
      logger.success(`CFBundleDisplayName is already in sync (${targetAppName})`);
    } else if (mode === 'dry-run') {
      logger.warn(
        `Would update CFBundleDisplayName: ${[...uniqueNames].join(', ')} → ${targetAppName}`,
      );
    } else if (mode === 'validate') {
      logger.error(`CFBundleDisplayName mismatch!`);
      logger.detail(`Expected: ${targetAppName}`);
      logger.detail(`Actual: ${[...uniqueNames].join(', ')}`);
      throw new Error('CFBundleDisplayName not in sync with pwa-config.json');
    } else {
      content = content.replace(
        /INFOPLIST_KEY_CFBundleDisplayName = "[^"]+"/g,
        `INFOPLIST_KEY_CFBundleDisplayName = "${targetAppName}"`,
      );
      result.displayNameUpdated = true;
      logger.success(`Updated CFBundleDisplayName: ${targetAppName}`);
    }
  }

  if (result.bundleIdUpdated || result.displayNameUpdated) {
    fs.writeFileSync(pbxprojPath, content);
    logger.success('project.pbxproj written');
  }

  return result;
}
