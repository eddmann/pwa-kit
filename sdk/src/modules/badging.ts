/**
 * Badging Module API
 *
 * Provides app icon badge management.
 * Aligned with the Web Badging API.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/Badging_API
 *
 * @module badging
 */

import { bridge } from '../bridge';

/**
 * Badging module for app icon badge management.
 * Aligned with the Web Badging API (navigator.setAppBadge/clearAppBadge).
 *
 * @example
 * ```typescript
 * import { badging } from '@pwa-kit/sdk';
 *
 * // Set badge count
 * await badging.setAppBadge(5);
 *
 * // Set badge without count (just shows indicator)
 * await badging.setAppBadge();
 *
 * // Clear badge
 * await badging.clearAppBadge();
 * ```
 */
export const badging = {
  /**
   * Sets the app icon badge.
   *
   * Aligned with navigator.setAppBadge().
   *
   * @param count - Badge count. If omitted or 0, shows a plain indicator.
   *                On iOS, 0 clears the badge.
   */
  async setAppBadge(count?: number): Promise<void> {
    await bridge.call('notifications', 'setBadge', { count: count ?? 0 });
  },

  /**
   * Clears the app icon badge.
   *
   * Aligned with navigator.clearAppBadge().
   */
  async clearAppBadge(): Promise<void> {
    await bridge.call('notifications', 'setBadge', { count: 0 });
  },
};
