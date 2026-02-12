import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { logger } from '../utils/logger.js';

const REPO = 'eddmann/pwa-kit';

interface GitHubRelease {
  tag_name: string;
  assets: Array<{
    name: string;
    browser_download_url: string;
  }>;
}

export async function downloadTemplate(
  targetDir: string,
  version?: string,
): Promise<boolean> {
  logger.step('Downloading PWAKit template...');

  const apiUrl = version
    ? `https://api.github.com/repos/${REPO}/releases/tags/${version}`
    : `https://api.github.com/repos/${REPO}/releases/latest`;

  try {
    const response = await fetch(apiUrl, {
      headers: { Accept: 'application/vnd.github.v3+json' },
      signal: AbortSignal.timeout(15_000),
    });

    if (!response.ok) {
      logger.error(`Failed to fetch release info: ${response.status} ${response.statusText}`);
      return false;
    }

    const release = (await response.json()) as GitHubRelease;
    const asset = release.assets.find((a) => a.name.endsWith('.tar.gz'));

    if (!asset) {
      logger.error(`No template archive found in release ${release.tag_name}`);
      return false;
    }

    logger.info(`Downloading ${asset.name} (${release.tag_name})...`);

    const archiveResponse = await fetch(asset.browser_download_url, {
      signal: AbortSignal.timeout(60_000),
    });

    if (!archiveResponse.ok) {
      logger.error('Failed to download template archive');
      return false;
    }

    // Write archive to temp file, extract with tar
    fs.mkdirSync(targetDir, { recursive: true });
    const tempArchive = path.join(targetDir, '.pwakit-template.tar.gz');

    try {
      const buffer = Buffer.from(await archiveResponse.arrayBuffer());
      fs.writeFileSync(tempArchive, buffer);
      execSync(`tar -xzf "${tempArchive}" -C "${targetDir}"`, { stdio: 'pipe' });
      logger.success(`Template extracted to: ${targetDir}`);
      return true;
    } finally {
      if (fs.existsSync(tempArchive)) fs.unlinkSync(tempArchive);
    }
  } catch (err) {
    if (err instanceof Error) {
      logger.error(`Template download failed: ${err.message}`);
    }
    return false;
  }
}
