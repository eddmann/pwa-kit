/**
 * App Module API
 *
 * Provides app lifecycle and meta operations.
 *
 * @module ios/app
 */

import { bridge } from '../bridge';

/**
 * App version information.
 */
export interface AppVersion {
  /** Marketing version (e.g., '1.0.0') */
  version: string;
  /** Build number (e.g., '42') */
  build: string;
}

/**
 * Result from requesting app review.
 */
export interface ReviewResult {
  /** Whether the review request was presented */
  presented: boolean;
}

/**
 * App module for app lifecycle and meta operations.
 *
 * @example
 * ```typescript
 * import { ios } from '@eddmann/pwa-kit-sdk';
 *
 * // Get app version
 * const version = await ios.app.getVersion();
 * console.log(`Version ${version.version} (${version.build})`);
 *
 * // Request app review
 * await ios.app.requestReview();
 *
 * // Open app settings
 * await ios.app.openSettings();
 * ```
 */
export const app = {
  /**
   * Gets the app version and build number.
   *
   * @returns App version information
   */
  async getVersion(): Promise<AppVersion> {
    return bridge.call<AppVersion>('app', 'getVersion');
  },

  /**
   * Requests the user to rate the app.
   *
   * Uses SKStoreReviewController.requestReview() which may or may not
   * show the rating dialog depending on Apple's rate limiting.
   *
   * @returns Whether the review dialog was presented
   */
  async requestReview(): Promise<ReviewResult> {
    return bridge.call<ReviewResult>('app', 'requestReview');
  },

  /**
   * Opens the app's settings page in the Settings app.
   *
   * Useful for directing users to enable permissions they previously denied.
   */
  async openSettings(): Promise<void> {
    await bridge.call('app', 'openSettings');
  },
};
