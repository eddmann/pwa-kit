import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import plist from 'plist';
import { syncPlist } from '../../src/sync/plist.js';

const FIXTURE = path.join(__dirname, '..', 'fixtures', 'sample-Info.plist');

describe('syncPlist', () => {
  let tmpDir: string;
  let tmpFile: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'plist-test-'));
    tmpFile = path.join(tmpDir, 'Info.plist');
    fs.copyFileSync(FIXTURE, tmpFile);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('updates WKAppBoundDomains', () => {
    const modified = syncPlist(tmpFile, ['new.example.com', 'api.example.com'], 'any', 'My App', 'apply');
    expect(modified).toBe(true);

    const data = plist.parse(fs.readFileSync(tmpFile, 'utf-8')) as Record<string, unknown>;
    const domains = data['WKAppBoundDomains'] as string[];
    expect(domains).toContain('new.example.com');
    expect(domains).toContain('api.example.com');
    expect(domains).not.toContain('old.example.com');
  });

  it('updates orientation to portrait', () => {
    syncPlist(tmpFile, ['old.example.com'], 'portrait', 'My App', 'apply');

    const data = plist.parse(fs.readFileSync(tmpFile, 'utf-8')) as Record<string, unknown>;
    const orientations = data['UISupportedInterfaceOrientations'] as string[];
    expect(orientations).toEqual(['UIInterfaceOrientationPortrait']);
    const ipad = data['UISupportedInterfaceOrientations~ipad'] as string[];
    expect(ipad).toEqual(['UIInterfaceOrientationPortrait']);
  });

  it('dry-run does not modify file', () => {
    const before = fs.readFileSync(tmpFile, 'utf-8');
    syncPlist(tmpFile, ['new.example.com'], 'portrait', 'New Name', 'dry-run');
    const after = fs.readFileSync(tmpFile, 'utf-8');
    expect(after).toBe(before);
  });

  it('reports no change when already in sync', () => {
    const modified = syncPlist(
      tmpFile,
      ['old.example.com'],
      'any',
      'My App',
      'apply',
    );
    expect(modified).toBe(false);
  });

  it('updates CFBundleDisplayName and CFBundleName', () => {
    const modified = syncPlist(tmpFile, ['old.example.com'], 'any', 'New Name', 'apply');
    expect(modified).toBe(true);

    const data = plist.parse(fs.readFileSync(tmpFile, 'utf-8')) as Record<string, unknown>;
    expect(data['CFBundleDisplayName']).toBe('New Name');
    expect(data['CFBundleName']).toBe('New Name');
  });

  it('reports no change when names already in sync', () => {
    const modified = syncPlist(tmpFile, ['old.example.com'], 'any', 'My App', 'apply');
    expect(modified).toBe(false);

    const data = plist.parse(fs.readFileSync(tmpFile, 'utf-8')) as Record<string, unknown>;
    expect(data['CFBundleDisplayName']).toBe('My App');
    expect(data['CFBundleName']).toBe('My App');
  });
});
