import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { syncPbxproj } from '../../src/sync/pbxproj.js';

const FIXTURE = path.join(__dirname, '..', 'fixtures', 'sample.pbxproj');

describe('syncPbxproj', () => {
  let tmpDir: string;
  let tmpFile: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pbxproj-test-'));
    tmpFile = path.join(tmpDir, 'project.pbxproj');
    fs.copyFileSync(FIXTURE, tmpFile);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('updates bundle ID in all occurrences', () => {
    const result = syncPbxproj(tmpFile, 'com.new.bundle', 'apply');
    expect(result.bundleIdUpdated).toBe(true);

    const content = fs.readFileSync(tmpFile, 'utf-8');
    const matches = content.match(/PRODUCT_BUNDLE_IDENTIFIER = com\.new\.bundle;/g);
    expect(matches).toHaveLength(4);
    expect(content).not.toContain('com.example.myapp');
  });

  it('reports already in sync', () => {
    const result = syncPbxproj(tmpFile, 'com.example.myapp', 'apply');
    expect(result.bundleIdUpdated).toBe(false);
  });

  it('dry-run does not modify file', () => {
    const before = fs.readFileSync(tmpFile, 'utf-8');
    syncPbxproj(tmpFile, 'com.new.bundle', 'dry-run');
    const after = fs.readFileSync(tmpFile, 'utf-8');
    expect(after).toBe(before);
  });

  it('validate throws on mismatch', () => {
    expect(() => syncPbxproj(tmpFile, 'com.new.bundle', 'validate')).toThrow();
  });
});
