import { Command } from 'commander';
import fs from 'node:fs';
import { projectPaths } from '../utils/paths.js';
import { logger } from '../utils/logger.js';
import { runSync } from '../sync/index.js';
import { detectProject } from '../template/detect.js';

export const syncCommand = new Command('sync')
  .description('Sync pwa-config.json to the Xcode project')
  .option('-n, --dry-run', 'show what would change without modifying files')
  .option('-v, --validate', 'validate configuration without modifying files')
  .action(async (opts: { dryRun?: boolean; validate?: boolean }) => {
    const projectRoot = detectProject(process.cwd());
    if (!projectRoot) {
      logger.error('PWAKitApp.xcodeproj not found. Run this from the project root.');
      process.exit(1);
    }

    const paths = projectPaths(projectRoot);

    if (!fs.existsSync(paths.configFile)) {
      logger.error(`Config file not found: ${paths.configFile}`);
      logger.error('Run "pwa-kit init" first to generate pwa-config.json');
      process.exit(1);
    }

    const mode = opts.validate ? 'validate' : opts.dryRun ? 'dry-run' : 'apply';

    try {
      await runSync(paths, mode);
    } catch (err) {
      if (err instanceof Error) {
        logger.error(err.message);
      }
      process.exit(1);
    }
  });
