/**
 * PWAKit Platform Detection Utilities
 *
 * Utilities for detecting whether the app is running in the native PWAKit wrapper
 * or in a regular browser environment.
 */

/**
 * Platform type enumeration.
 */
export type Platform = 'ios' | 'browser' | 'unknown';

/**
 * Information about the current platform environment.
 */
export interface PlatformDetectionInfo {
  /** Whether running inside the native PWAKit app wrapper */
  isNative: boolean;
  /** Whether the webkit message handlers are available */
  hasMessageHandlers: boolean;
  /** Whether PWAKit is present in the user agent */
  hasPWAKitUserAgent: boolean;
  /** The detected platform type */
  platform: Platform;
  /** The raw user agent string (if available) */
  userAgent: string | null;
}

/**
 * Checks if webkit.messageHandlers.pwakit is available.
 *
 * This is the primary indicator that the code is running inside the
 * PWAKit native iOS wrapper, as the bridge message handler is only
 * available in the WKWebView context.
 *
 * @returns true if webkit message handlers are available
 */
export function hasMessageHandlers(): boolean {
  if (typeof window === 'undefined') {
    return false;
  }

  return (
    typeof window.webkit?.messageHandlers?.pwakit?.postMessage === 'function'
  );
}

/**
 * Checks if 'PWAKit' is present in the user agent string.
 *
 * PWAKit appends 'PWAKit' to the user agent string when running
 * inside the native wrapper, providing an additional detection signal.
 *
 * @returns true if PWAKit is found in the user agent
 */
export function hasPWAKitInUserAgent(): boolean {
  if (typeof navigator === 'undefined') {
    return false;
  }

  return navigator.userAgent.includes('PWAKit');
}

/**
 * Detects the current platform.
 *
 * @returns The detected platform type
 */
export function detectPlatform(): Platform {
  if (typeof navigator === 'undefined') {
    return 'unknown';
  }

  // Check for iOS indicators in combination with native wrapper
  const userAgent = navigator.userAgent;
  const isIOSDevice =
    /iPad|iPhone|iPod/.test(userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

  if (hasMessageHandlers() || hasPWAKitInUserAgent()) {
    return 'ios';
  }

  if (isIOSDevice) {
    return 'ios';
  }

  // Check if running in a browser environment
  if (typeof window !== 'undefined' && typeof document !== 'undefined') {
    return 'browser';
  }

  return 'unknown';
}

/**
 * Gets the user agent string.
 *
 * @returns The user agent string or null if not available
 */
export function getUserAgent(): string | null {
  if (typeof navigator === 'undefined') {
    return null;
  }
  return navigator.userAgent;
}

/**
 * Gets comprehensive platform detection information.
 *
 * This function combines all detection methods to provide a complete
 * picture of the current runtime environment.
 *
 * @returns Complete platform detection information
 *
 * @example
 * ```typescript
 * import { getPlatformInfo } from '@pwa-kit/sdk';
 *
 * const info = getPlatformInfo();
 * if (info.isNative) {
 *   // Running in PWAKit native wrapper
 *   console.log('Native app on', info.platform);
 * } else {
 *   // Running in regular browser
 *   console.log('Browser environment');
 * }
 * ```
 */
export function getPlatformInfo(): PlatformDetectionInfo {
  const messageHandlers = hasMessageHandlers();
  const pwaShellUA = hasPWAKitInUserAgent();

  return {
    isNative: messageHandlers || pwaShellUA,
    hasMessageHandlers: messageHandlers,
    hasPWAKitUserAgent: pwaShellUA,
    platform: detectPlatform(),
    userAgent: getUserAgent(),
  };
}

/**
 * Whether the code is running inside the native PWAKit app wrapper.
 *
 * This is a convenience boolean that returns true if either:
 * - The webkit.messageHandlers.pwakit is available
 * - 'PWAKit' is present in the user agent
 *
 * Use this for quick checks when you need to conditionally enable native features.
 *
 * @example
 * ```typescript
 * import { isNative } from '@pwa-kit/sdk';
 *
 * if (isNative) {
 *   // Use native features via the bridge
 *   await haptics.impact('medium');
 * } else {
 *   // Fallback for browser
 *   console.log('Native features not available');
 * }
 * ```
 */
export const isNative: boolean = hasMessageHandlers() || hasPWAKitInUserAgent();

/**
 * The current platform information.
 *
 * This is a convenience export of getPlatformInfo() for cases where
 * you need the full detection info without calling a function.
 *
 * Note: This is evaluated once at module load time. If detection
 * needs to be re-evaluated (e.g., after dynamic script injection),
 * call getPlatformInfo() instead.
 *
 * @example
 * ```typescript
 * import { platformInfo } from '@pwa-kit/sdk';
 *
 * console.log('Running on:', platformInfo.platform);
 * console.log('Is native:', platformInfo.isNative);
 * ```
 */
export const platformInfo: PlatformDetectionInfo = getPlatformInfo();
