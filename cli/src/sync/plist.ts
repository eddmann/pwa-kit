import fs from 'node:fs';
import plist from 'plist';
import { logger } from '../utils/logger.js';
import type { Orientation } from '../utils/validation.js';

const ORIENTATION_MAP: Record<string, string[]> = {
  portrait: ['UIInterfaceOrientationPortrait'],
  landscape: ['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
  any: [
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight',
  ],
};

function setsEqual(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const setA = new Set(a);
  return b.every((item) => setA.has(item));
}

export function syncPlist(
  plistPath: string,
  domains: string[],
  orientationLock: Orientation,
  mode: 'apply' | 'dry-run' | 'validate',
): boolean {
  if (!fs.existsSync(plistPath)) {
    logger.warn('Info.plist not found, skipping');
    return false;
  }

  const raw = fs.readFileSync(plistPath, 'utf-8');
  const data = plist.parse(raw) as Record<string, unknown>;
  let modified = false;

  // Sync WKAppBoundDomains
  logger.step('Syncing WKAppBoundDomains...');
  const currentDomains = (data['WKAppBoundDomains'] as string[]) ?? [];

  if (setsEqual(currentDomains, domains)) {
    logger.success('WKAppBoundDomains is already in sync');
  } else if (mode === 'dry-run') {
    logger.warn(`Would update WKAppBoundDomains: [${currentDomains.join(', ')}] → [${domains.join(', ')}]`);
  } else if (mode === 'validate') {
    logger.error('WKAppBoundDomains mismatch!');
    logger.detail(`Expected: [${domains.join(', ')}]`);
    logger.detail(`Actual: [${currentDomains.join(', ')}]`);
    throw new Error('WKAppBoundDomains not in sync with pwa-config.json');
  } else {
    data['WKAppBoundDomains'] = domains;
    modified = true;
    logger.success(`Updated WKAppBoundDomains: [${domains.join(', ')}]`);
  }

  // Sync orientation
  logger.step('Syncing orientation lock...');
  const targetOrientations = ORIENTATION_MAP[orientationLock];
  if (!targetOrientations) {
    logger.error(`Unknown orientationLock value: ${orientationLock}`);
    throw new Error(`Invalid orientationLock: ${orientationLock}`);
  }

  const currentOrientations = (data['UISupportedInterfaceOrientations'] as string[]) ?? [];
  const currentIpad = (data['UISupportedInterfaceOrientations~ipad'] as string[]) ?? [];

  const orientationsMatch =
    setsEqual(currentOrientations, targetOrientations) && setsEqual(currentIpad, targetOrientations);

  if (orientationsMatch) {
    logger.success(`UISupportedInterfaceOrientations is already in sync (${orientationLock})`);
  } else if (mode === 'dry-run') {
    logger.warn(
      `Would update UISupportedInterfaceOrientations: [${currentOrientations.join(', ')}] → [${targetOrientations.join(', ')}]`,
    );
  } else if (mode === 'validate') {
    logger.error('UISupportedInterfaceOrientations mismatch!');
    logger.detail(`Expected: [${targetOrientations.join(', ')}]`);
    logger.detail(`Actual: [${currentOrientations.join(', ')}]`);
    throw new Error('UISupportedInterfaceOrientations not in sync with pwa-config.json');
  } else {
    data['UISupportedInterfaceOrientations'] = targetOrientations;
    data['UISupportedInterfaceOrientations~ipad'] = targetOrientations;
    modified = true;
    logger.success(`Updated UISupportedInterfaceOrientations: [${targetOrientations.join(', ')}] (${orientationLock})`);
  }

  if (modified) {
    logger.step('Writing updated Info.plist...');
    fs.writeFileSync(plistPath, plist.build(data as plist.PlistObject));
    logger.success('Info.plist updated successfully');
  }

  return modified;
}
