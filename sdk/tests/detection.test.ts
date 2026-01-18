/**
 * Tests for platform detection utilities
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  hasMessageHandlers,
  hasPWAKitInUserAgent,
  detectPlatform,
  getUserAgent,
  getPlatformInfo,
  type PlatformDetectionInfo,
} from '../src/detection';

describe('detection utilities', () => {
  // Store original values
  const originalWindow = globalThis.window;
  const originalNavigator = globalThis.navigator;

  beforeEach(() => {
    // Reset any mocks
    vi.restoreAllMocks();
  });

  afterEach(() => {
    // Restore original globals
    vi.unstubAllGlobals();
  });

  describe('hasMessageHandlers', () => {
    it('returns false when window is undefined', () => {
      vi.stubGlobal('window', undefined);
      expect(hasMessageHandlers()).toBe(false);
    });

    it('returns false when webkit is not defined', () => {
      vi.stubGlobal('window', {});
      expect(hasMessageHandlers()).toBe(false);
    });

    it('returns false when messageHandlers is not defined', () => {
      vi.stubGlobal('window', { webkit: {} });
      expect(hasMessageHandlers()).toBe(false);
    });

    it('returns false when pwakit is not defined', () => {
      vi.stubGlobal('window', {
        webkit: { messageHandlers: {} },
      });
      expect(hasMessageHandlers()).toBe(false);
    });

    it('returns false when postMessage is not a function', () => {
      vi.stubGlobal('window', {
        webkit: {
          messageHandlers: {
            pwakit: { postMessage: 'not a function' },
          },
        },
      });
      expect(hasMessageHandlers()).toBe(false);
    });

    it('returns true when pwakit.postMessage is a function', () => {
      vi.stubGlobal('window', {
        webkit: {
          messageHandlers: {
            pwakit: { postMessage: vi.fn() },
          },
        },
      });
      expect(hasMessageHandlers()).toBe(true);
    });
  });

  describe('hasPWAKitInUserAgent', () => {
    it('returns false when navigator is undefined', () => {
      vi.stubGlobal('navigator', undefined);
      expect(hasPWAKitInUserAgent()).toBe(false);
    });

    it('returns false when PWAKit is not in user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      });
      expect(hasPWAKitInUserAgent()).toBe(false);
    });

    it('returns true when PWAKit is in user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) PWAKit/1.0.0 Safari/604.1',
      });
      expect(hasPWAKitInUserAgent()).toBe(true);
    });
  });

  describe('detectPlatform', () => {
    it('returns unknown when navigator is undefined', () => {
      vi.stubGlobal('navigator', undefined);
      expect(detectPlatform()).toBe('unknown');
    });

    it('returns ios when message handlers are available', () => {
      vi.stubGlobal('navigator', {
        userAgent: 'Some random user agent',
        platform: 'Win32',
        maxTouchPoints: 0,
      });
      vi.stubGlobal('window', {
        webkit: {
          messageHandlers: {
            pwakit: { postMessage: vi.fn() },
          },
        },
      });
      expect(detectPlatform()).toBe('ios');
    });

    it('returns ios when PWAKit is in user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent: 'PWAKit/1.0.0',
        platform: 'Win32',
        maxTouchPoints: 0,
      });
      vi.stubGlobal('window', {});
      expect(detectPlatform()).toBe('ios');
    });

    it('returns ios for iPhone user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
        platform: 'iPhone',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {});
      expect(detectPlatform()).toBe('ios');
    });

    it('returns ios for iPad user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
        platform: 'iPad',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {});
      expect(detectPlatform()).toBe('ios');
    });

    it('returns ios for iPod user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (iPod; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
        platform: 'iPod',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {});
      expect(detectPlatform()).toBe('ios');
    });

    it('returns ios for iPad Pro (MacIntel with touch)', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
        platform: 'MacIntel',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {});
      expect(detectPlatform()).toBe('ios');
    });

    it('returns browser for desktop Safari', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
        platform: 'MacIntel',
        maxTouchPoints: 0,
      });
      vi.stubGlobal('window', {});
      vi.stubGlobal('document', {});
      expect(detectPlatform()).toBe('browser');
    });

    it('returns browser for Chrome on Windows', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0',
        platform: 'Win32',
        maxTouchPoints: 0,
      });
      vi.stubGlobal('window', {});
      vi.stubGlobal('document', {});
      expect(detectPlatform()).toBe('browser');
    });
  });

  describe('getUserAgent', () => {
    it('returns null when navigator is undefined', () => {
      vi.stubGlobal('navigator', undefined);
      expect(getUserAgent()).toBeNull();
    });

    it('returns the user agent string', () => {
      const testUA = 'Test User Agent String';
      vi.stubGlobal('navigator', { userAgent: testUA });
      expect(getUserAgent()).toBe(testUA);
    });
  });

  describe('getPlatformInfo', () => {
    it('returns complete platform info for native environment', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 PWAKit/1.0.0',
        platform: 'iPhone',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {
        webkit: {
          messageHandlers: {
            pwakit: { postMessage: vi.fn() },
          },
        },
      });

      const info = getPlatformInfo();

      expect(info.isNative).toBe(true);
      expect(info.hasMessageHandlers).toBe(true);
      expect(info.hasPWAKitUserAgent).toBe(true);
      expect(info.platform).toBe('ios');
      expect(info.userAgent).toContain('PWAKit');
    });

    it('returns complete platform info for browser environment', () => {
      vi.stubGlobal('navigator', {
        userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0',
        platform: 'Win32',
        maxTouchPoints: 0,
      });
      vi.stubGlobal('window', {});
      vi.stubGlobal('document', {});

      const info = getPlatformInfo();

      expect(info.isNative).toBe(false);
      expect(info.hasMessageHandlers).toBe(false);
      expect(info.hasPWAKitUserAgent).toBe(false);
      expect(info.platform).toBe('browser');
      expect(info.userAgent).toContain('Chrome');
    });

    it('detects native when only message handlers are available', () => {
      vi.stubGlobal('navigator', {
        userAgent: 'Regular Safari',
        platform: 'iPhone',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {
        webkit: {
          messageHandlers: {
            pwakit: { postMessage: vi.fn() },
          },
        },
      });

      const info = getPlatformInfo();

      expect(info.isNative).toBe(true);
      expect(info.hasMessageHandlers).toBe(true);
      expect(info.hasPWAKitUserAgent).toBe(false);
    });

    it('detects native when only PWAKit is in user agent', () => {
      vi.stubGlobal('navigator', {
        userAgent: 'PWAKit/1.0.0',
        platform: 'iPhone',
        maxTouchPoints: 5,
      });
      vi.stubGlobal('window', {});

      const info = getPlatformInfo();

      expect(info.isNative).toBe(true);
      expect(info.hasMessageHandlers).toBe(false);
      expect(info.hasPWAKitUserAgent).toBe(true);
    });
  });
});
