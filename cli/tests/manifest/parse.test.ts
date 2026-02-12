import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { parseManifestValues, pickBestIcon } from '../../src/manifest/parse.js';
import type { WebManifest } from '../../src/manifest/parse.js';

const FIXTURE = path.join(__dirname, '..', 'fixtures', 'sample-manifest.json');

describe('parseManifestValues', () => {
  const manifest: WebManifest = JSON.parse(fs.readFileSync(FIXTURE, 'utf-8'));

  it('extracts short_name as name', () => {
    const values = parseManifestValues(manifest);
    expect(values.name).toBe('Sample');
  });

  it('falls back to name when short_name missing', () => {
    const values = parseManifestValues({ name: 'Full Name' });
    expect(values.name).toBe('Full Name');
  });

  it('extracts valid hex colors', () => {
    const values = parseManifestValues(manifest);
    expect(values.backgroundColor).toBe('#1a1a2e');
    expect(values.themeColor).toBe('#e94560');
  });

  it('ignores invalid colors', () => {
    const values = parseManifestValues({ background_color: 'red', theme_color: '#FFF' });
    expect(values.backgroundColor).toBe('');
    expect(values.themeColor).toBe('');
  });

  it('maps portrait-primary to portrait', () => {
    const values = parseManifestValues(manifest);
    expect(values.orientation).toBe('portrait');
  });

  it('maps landscape-primary to landscape', () => {
    const values = parseManifestValues({ orientation: 'landscape-primary' });
    expect(values.orientation).toBe('landscape');
  });

  it('extracts display mode', () => {
    const values = parseManifestValues(manifest);
    expect(values.display).toBe('standalone');
  });

  it('ignores unsupported display modes', () => {
    const values = parseManifestValues({ display: 'minimal-ui' });
    expect(values.display).toBe('');
  });
});

describe('pickBestIcon', () => {
  const manifest: WebManifest = JSON.parse(fs.readFileSync(FIXTURE, 'utf-8'));

  it('picks the largest non-maskable icon', () => {
    const icon = pickBestIcon(manifest);
    expect(icon).toBe('/icons/icon-1024.png');
  });

  it('skips maskable icons', () => {
    const icon = pickBestIcon({
      icons: [
        { src: '/maskable.png', sizes: '1024x1024', purpose: 'maskable' },
        { src: '/regular.png', sizes: '512x512' },
      ],
    });
    expect(icon).toBe('/regular.png');
  });

  it('returns null when no icons', () => {
    expect(pickBestIcon({ icons: [] })).toBeNull();
    expect(pickBestIcon({})).toBeNull();
  });
});
