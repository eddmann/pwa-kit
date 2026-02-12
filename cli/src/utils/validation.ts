export function isValidHttpsUrl(url: string): boolean {
  if (!url.startsWith('https://')) return false;
  return /^https:\/\/[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}(\/.*)?$/.test(url);
}

export function isValidHexColor(color: string): boolean {
  return /^#[0-9A-Fa-f]{6}$/.test(color);
}

export function isValidBundleId(bundleId: string): boolean {
  return /^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*)+$/.test(bundleId);
}

export function extractDomain(url: string): string {
  return url.replace(/^https:\/\/([^/]+).*/, '$1');
}

export function reverseDomain(domain: string): string {
  return domain.split('.').reverse().join('.');
}

export const VALID_ORIENTATIONS = ['any', 'portrait', 'landscape'] as const;
export type Orientation = (typeof VALID_ORIENTATIONS)[number];

export const VALID_DISPLAY_MODES = ['standalone', 'fullscreen'] as const;
export type DisplayMode = (typeof VALID_DISPLAY_MODES)[number];

export const ALL_FEATURES = [
  'notifications',
  'haptics',
  'biometrics',
  'secureStorage',
  'healthkit',
  'iap',
  'share',
  'print',
  'clipboard',
] as const;
export type Feature = (typeof ALL_FEATURES)[number];
