import fs from 'node:fs';
import { logger } from '../utils/logger.js';

interface ColorsetContents {
  colors: Array<{
    color: {
      'color-space': string;
      components: {
        alpha: string;
        blue: string;
        green: string;
        red: string;
      };
    };
    idiom: string;
  }>;
  info: {
    author: string;
    version: number;
  };
}

export function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const h = hex.replace('#', '');
  return {
    r: parseInt(h.slice(0, 2), 16) / 255,
    g: parseInt(h.slice(2, 4), 16) / 255,
    b: parseInt(h.slice(4, 6), 16) / 255,
  };
}

function makeColorsetJson(r: number, g: number, b: number): ColorsetContents {
  return {
    colors: [
      {
        color: {
          'color-space': 'srgb',
          components: {
            alpha: '1.000',
            blue: b.toFixed(3),
            green: g.toFixed(3),
            red: r.toFixed(3),
          },
        },
        idiom: 'universal',
      },
    ],
    info: {
      author: 'xcode',
      version: 1,
    },
  };
}

function readColorset(path: string): { r: number; g: number; b: number } | null {
  try {
    const data: ColorsetContents = JSON.parse(fs.readFileSync(path, 'utf-8'));
    const components = data.colors[0]?.color?.components;
    if (!components) return null;
    return {
      r: parseFloat(components.red),
      g: parseFloat(components.green),
      b: parseFloat(components.blue),
    };
  } catch {
    return null;
  }
}

function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}

export function syncColor(
  hexValue: string,
  colorsetPath: string,
  label: string,
  mode: 'apply' | 'dry-run' | 'validate',
): boolean {
  const { r, g, b } = hexToRgb(hexValue);
  const target = { r: round3(r), g: round3(g), b: round3(b) };
  const current = readColorset(colorsetPath);

  const currentRounded = current
    ? { r: round3(current.r), g: round3(current.g), b: round3(current.b) }
    : null;

  if (
    currentRounded &&
    currentRounded.r === target.r &&
    currentRounded.g === target.g &&
    currentRounded.b === target.b
  ) {
    logger.success(`${label} is already in sync (${hexValue})`);
    return false;
  }

  if (mode === 'dry-run') {
    logger.warn(`Would update ${label} → ${hexValue}`);
    return false;
  }

  if (mode === 'validate') {
    logger.error(`${label} mismatch!`);
    logger.detail(`Expected: rgb(${target.r}, ${target.g}, ${target.b}) (${hexValue})`);
    logger.detail(
      `Actual: ${currentRounded ? `rgb(${currentRounded.r}, ${currentRounded.g}, ${currentRounded.b})` : 'not set'}`,
    );
    throw new Error(`${label} not in sync with pwa-config.json`);
  }

  const colorsetData = makeColorsetJson(r, g, b);
  fs.writeFileSync(colorsetPath, JSON.stringify(colorsetData, null, 2) + '\n');
  logger.success(`Updated ${label}: ${hexValue}`);
  return true;
}
