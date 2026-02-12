import fs from 'node:fs';
import sharp from 'sharp';
import path from 'node:path';
import { logger } from '../utils/logger.js';
import type { ProjectPaths } from '../utils/paths.js';

interface IconTarget {
  width: number;
  height: number;
  outputPath: string;
}

export async function syncIcons(
  paths: ProjectPaths,
  mode: 'apply' | 'dry-run' | 'validate',
): Promise<void> {
  logger.step('Syncing app icons...');

  if (!fs.existsSync(paths.iconSource)) {
    logger.warn('AppIcon-source.png not found, skipping icon sync');
    logger.detail(`Place a source icon at: ${paths.iconSource}`);
    return;
  }

  const targets: IconTarget[] = [
    { width: 1024, height: 1024, outputPath: paths.appIcon },
    { width: 100, height: 100, outputPath: paths.launchIcon1x },
    { width: 200, height: 200, outputPath: paths.launchIcon2x },
    { width: 300, height: 300, outputPath: paths.launchIcon3x },
  ];

  const sourceMtime = fs.statSync(paths.iconSource).mtimeMs;
  const allUpToDate = targets.every(
    (t) => fs.existsSync(t.outputPath) && fs.statSync(t.outputPath).mtimeMs >= sourceMtime,
  );

  if (allUpToDate) {
    logger.success('App icons are already up to date');
    return;
  }

  if (mode === 'dry-run') {
    for (const t of targets) {
      logger.warn(`Would resize icon to ${t.width}x${t.height} → ${path.basename(t.outputPath)}`);
    }
    return;
  }

  if (mode === 'validate') {
    const outdated = targets
      .filter((t) => !fs.existsSync(t.outputPath) || fs.statSync(t.outputPath).mtimeMs < sourceMtime)
      .map((t) => path.basename(t.outputPath));
    if (outdated.length > 0) {
      logger.error(`Icon variants out of date: ${outdated.join(', ')}`);
      throw new Error('App icon variants not in sync with AppIcon-source.png');
    }
    return;
  }

  for (const t of targets) {
    fs.mkdirSync(path.dirname(t.outputPath), { recursive: true });
    await sharp(paths.iconSource).resize(t.width, t.height).png().toFile(t.outputPath);
    logger.success(`Resized icon to ${t.width}x${t.height} → ${path.basename(t.outputPath)}`);
  }
}
