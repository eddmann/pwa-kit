import fs from 'node:fs';
import path from 'node:path';

/**
 * Walk up from `startDir` looking for PWAKitApp.xcodeproj.
 * Also checks immediate child directories (e.g. kit/).
 * Returns the directory containing it, or null if not found.
 */
export function detectProject(startDir: string): string | null {
  let dir = path.resolve(startDir);
  const root = path.parse(dir).root;

  while (dir !== root) {
    if (!fs.existsSync(dir)) {
      dir = path.dirname(dir);
      continue;
    }

    if (fs.existsSync(path.join(dir, 'PWAKitApp.xcodeproj'))) {
      return dir;
    }

    // Check immediate child directories
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory() && fs.existsSync(path.join(dir, entry.name, 'PWAKitApp.xcodeproj'))) {
        return path.join(dir, entry.name);
      }
    }

    dir = path.dirname(dir);
  }

  return null;
}
