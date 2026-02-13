import fs from 'node:fs';
import { logger } from '../utils/logger.js';

export interface PbxprojSyncResult {
  bundleIdUpdated: boolean;
}

export function syncPbxproj(
  pbxprojPath: string,
  targetBundleId: string,
  mode: 'apply' | 'dry-run' | 'validate',
): PbxprojSyncResult {
  const result: PbxprojSyncResult = { bundleIdUpdated: false };

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

  if (result.bundleIdUpdated) {
    fs.writeFileSync(pbxprojPath, content);
    logger.success('project.pbxproj written');
  }

  return result;
}
