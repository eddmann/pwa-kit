import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { hexToRgb, syncColor } from '../../src/sync/colorset.js';

describe('hexToRgb', () => {
  it('converts white', () => {
    expect(hexToRgb('#FFFFFF')).toEqual({ r: 1, g: 1, b: 1 });
  });

  it('converts black', () => {
    expect(hexToRgb('#000000')).toEqual({ r: 0, g: 0, b: 0 });
  });

  it('converts arbitrary color', () => {
    const { r, g, b } = hexToRgb('#8B83FF');
    expect(r).toBeCloseTo(0.545, 2);
    expect(g).toBeCloseTo(0.514, 2);
    expect(b).toBeCloseTo(1.0, 2);
  });
});

describe('syncColor', () => {
  let tmpDir: string;
  let tmpFile: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'colorset-test-'));
    tmpFile = path.join(tmpDir, 'Contents.json');
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('creates colorset file with correct RGB values', () => {
    const changed = syncColor('#FF0000', tmpFile, 'TestColor', 'apply');
    expect(changed).toBe(true);

    const data = JSON.parse(fs.readFileSync(tmpFile, 'utf-8'));
    expect(data.colors[0].color.components.red).toBe('1.000');
    expect(data.colors[0].color.components.green).toBe('0.000');
    expect(data.colors[0].color.components.blue).toBe('0.000');
  });

  it('reports no change when already in sync', () => {
    syncColor('#FF0000', tmpFile, 'TestColor', 'apply');
    const changed = syncColor('#FF0000', tmpFile, 'TestColor', 'apply');
    expect(changed).toBe(false);
  });

  it('dry-run does not create file', () => {
    syncColor('#FF0000', tmpFile, 'TestColor', 'dry-run');
    expect(fs.existsSync(tmpFile)).toBe(false);
  });
});
