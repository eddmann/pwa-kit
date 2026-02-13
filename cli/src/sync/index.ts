import { loadConfig } from '../config/load.js';
import type { ProjectPaths } from '../utils/paths.js';
import { logger } from '../utils/logger.js';
import { syncPbxproj } from './pbxproj.js';
import { syncPlist } from './plist.js';
import { syncColor } from './colorset.js';
import { syncIcons } from './icons.js';
import { validatePrivacy } from './privacy.js';

export type SyncMode = 'apply' | 'dry-run' | 'validate';

export async function runSync(paths: ProjectPaths, mode: SyncMode): Promise<void> {
  logger.step('Reading pwa-config.json...');
  const config = loadConfig(paths.configFile);

  // pbxproj sync
  logger.step('Syncing project.pbxproj...');
  syncPbxproj(paths.pbxproj, config.app.bundleId, mode);

  // Plist sync (domains + orientation)
  const allDomains = [...new Set([...config.origins.allowed, ...config.origins.auth])];
  logger.detail(`Allowed origins: [${config.origins.allowed.join(', ')}]`);
  logger.detail(`Auth origins: [${config.origins.auth.join(', ')}]`);
  logger.detail(`Combined: [${allDomains.join(', ')}]`);
  syncPlist(paths.infoPlist, allDomains, config.appearance.orientationLock, config.app.name, mode);

  // Privacy validation (read-only, always runs)
  const privacyErrors = validatePrivacy(paths.infoPlist, config.features);

  // Color sync
  if (config.appearance.backgroundColor || config.appearance.themeColor) {
    logger.step('Syncing appearance colors...');
  }
  if (config.appearance.backgroundColor) {
    syncColor(config.appearance.backgroundColor, paths.launchBackground, 'LaunchBackground.colorset', mode);
  }
  if (config.appearance.themeColor) {
    syncColor(config.appearance.themeColor, paths.accentColor, 'AccentColor.colorset', mode);
  }

  // Icon sync
  await syncIcons(paths, mode);

  // Summary
  console.log();
  if (privacyErrors.length > 0) {
    logger.error(`Validation failed with ${privacyErrors.length} error(s)`);
    for (const err of privacyErrors) {
      logger.detail(`- ${err}`);
    }
    process.exitCode = 1;
  } else {
    logger.success('Configuration is valid and in sync');
  }
}
