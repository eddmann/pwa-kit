import fs from 'node:fs';
import { logger } from '../utils/logger.js';

function makeAbsoluteUrl(src: string, baseUrl: string): string {
  if (src.startsWith('http')) return src;
  if (src.startsWith('/')) return `${baseUrl}${src}`;
  return `${baseUrl}/${src}`;
}

export async function downloadIcon(
  iconSrc: string,
  baseUrl: string,
  outputPath: string,
): Promise<boolean> {
  const iconUrl = makeAbsoluteUrl(iconSrc, baseUrl);
  logger.info(`Downloading icon: ${iconUrl}`);

  try {
    const response = await fetch(iconUrl, { signal: AbortSignal.timeout(30_000) });
    if (!response.ok) {
      logger.warn('Failed to download icon');
      return false;
    }

    const buffer = Buffer.from(await response.arrayBuffer());

    // Basic check: PNG starts with magic bytes, JPEG with FF D8
    const isPng = buffer[0] === 0x89 && buffer[1] === 0x50;
    const isJpeg = buffer[0] === 0xff && buffer[1] === 0xd8;
    if (!isPng && !isJpeg) {
      logger.warn('Downloaded file is not a valid image');
      return false;
    }

    fs.writeFileSync(outputPath, buffer);
    logger.success(`Source icon saved to: ${outputPath}`);
    return true;
  } catch {
    logger.warn('Failed to download icon');
    return false;
  }
}
