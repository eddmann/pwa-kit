import { describe, it, expect } from 'vitest';
import {
  isValidHttpsUrl,
  isValidHexColor,
  isValidBundleId,
  extractDomain,
  reverseDomain,
} from '../../src/utils/validation.js';

describe('isValidHttpsUrl', () => {
  it('accepts valid HTTPS URLs', () => {
    expect(isValidHttpsUrl('https://example.com')).toBe(true);
    expect(isValidHttpsUrl('https://app.example.com')).toBe(true);
    expect(isValidHttpsUrl('https://app.example.com/path')).toBe(true);
    expect(isValidHttpsUrl('https://pwakit-example.eddmann.workers.dev')).toBe(true);
  });

  it('rejects non-HTTPS URLs', () => {
    expect(isValidHttpsUrl('http://example.com')).toBe(false);
    expect(isValidHttpsUrl('ftp://example.com')).toBe(false);
    expect(isValidHttpsUrl('example.com')).toBe(false);
  });

  it('rejects invalid URLs', () => {
    expect(isValidHttpsUrl('https://')).toBe(false);
    expect(isValidHttpsUrl('https://.')).toBe(false);
    expect(isValidHttpsUrl('')).toBe(false);
  });
});

describe('isValidHexColor', () => {
  it('accepts valid 6-digit hex colors', () => {
    expect(isValidHexColor('#FFFFFF')).toBe(true);
    expect(isValidHexColor('#000000')).toBe(true);
    expect(isValidHexColor('#8B83FF')).toBe(true);
    expect(isValidHexColor('#1a1a2e')).toBe(true);
  });

  it('rejects invalid hex colors', () => {
    expect(isValidHexColor('#FFF')).toBe(false);
    expect(isValidHexColor('FFFFFF')).toBe(false);
    expect(isValidHexColor('#GGGGGG')).toBe(false);
    expect(isValidHexColor('')).toBe(false);
    expect(isValidHexColor('#12345')).toBe(false);
    expect(isValidHexColor('#1234567')).toBe(false);
  });
});

describe('isValidBundleId', () => {
  it('accepts valid bundle IDs', () => {
    expect(isValidBundleId('com.example.app')).toBe(true);
    expect(isValidBundleId('dev.workers.eddmann.pwakit-example')).toBe(true);
    expect(isValidBundleId('io.github.myapp')).toBe(true);
  });

  it('rejects invalid bundle IDs', () => {
    expect(isValidBundleId('com')).toBe(false);
    expect(isValidBundleId('.com.example')).toBe(false);
    expect(isValidBundleId('1com.example')).toBe(false);
    expect(isValidBundleId('')).toBe(false);
  });
});

describe('extractDomain', () => {
  it('extracts domain from URL', () => {
    expect(extractDomain('https://example.com')).toBe('example.com');
    expect(extractDomain('https://app.example.com/path')).toBe('app.example.com');
    expect(extractDomain('https://pwakit-example.eddmann.workers.dev')).toBe(
      'pwakit-example.eddmann.workers.dev',
    );
  });
});

describe('reverseDomain', () => {
  it('reverses domain segments', () => {
    expect(reverseDomain('example.com')).toBe('com.example');
    expect(reverseDomain('app.example.com')).toBe('com.example.app');
    expect(reverseDomain('pwakit-example.eddmann.workers.dev')).toBe(
      'dev.workers.eddmann.pwakit-example',
    );
  });
});
