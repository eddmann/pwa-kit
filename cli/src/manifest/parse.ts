import { isValidHexColor } from '../utils/validation.js';
import type { DisplayMode, Orientation } from '../utils/validation.js';

export interface ManifestValues {
  name: string;
  backgroundColor: string;
  themeColor: string;
  orientation: Orientation | '';
  display: DisplayMode | '';
}

export interface ManifestIcon {
  src: string;
  sizes?: string;
  purpose?: string;
  type?: string;
}

export interface WebManifest {
  name?: string;
  short_name?: string;
  background_color?: string;
  theme_color?: string;
  orientation?: string;
  display?: string;
  icons?: ManifestIcon[];
}

const PORTRAIT_VALUES = new Set(['portrait', 'portrait-primary', 'portrait-secondary', 'natural']);
const LANDSCAPE_VALUES = new Set(['landscape', 'landscape-primary', 'landscape-secondary']);

export function parseManifestValues(manifest: WebManifest): ManifestValues {
  const name = manifest.short_name || manifest.name || '';

  const bgColor = manifest.background_color ?? '';
  const themeColor = manifest.theme_color ?? '';

  let orientation: Orientation | '' = '';
  if (manifest.orientation) {
    if (PORTRAIT_VALUES.has(manifest.orientation)) orientation = 'portrait';
    else if (LANDSCAPE_VALUES.has(manifest.orientation)) orientation = 'landscape';
    else if (manifest.orientation === 'any') orientation = 'any';
  }

  let display: DisplayMode | '' = '';
  if (manifest.display === 'standalone' || manifest.display === 'fullscreen') {
    display = manifest.display;
  }

  return {
    name,
    backgroundColor: isValidHexColor(bgColor) ? bgColor : '',
    themeColor: isValidHexColor(themeColor) ? themeColor : '',
    orientation,
    display,
  };
}

export function pickBestIcon(manifest: WebManifest): string | null {
  const icons = manifest.icons ?? [];
  if (icons.length === 0) return null;

  let bestIcon: string | null = null;
  let bestSize = 0;

  for (const icon of icons) {
    if (icon.purpose === 'maskable') continue;

    const sizeStr = (icon.sizes ?? '0x0').split(' ')[0];
    let size = 0;
    try {
      const [w, h] = sizeStr.toLowerCase().split('x').map(Number);
      size = Math.min(w, h);
    } catch {
      size = 0;
    }

    if (size > bestSize || (size === bestSize && icon.src.toLowerCase().includes('.png'))) {
      bestSize = size;
      bestIcon = icon.src;
    }
  }

  return bestIcon;
}
