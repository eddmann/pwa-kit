/**
 * Vibration Module API
 *
 * Provides simple vibration feedback.
 * Aligned with the Web Vibration API.
 *
 * Note: iOS Safari doesn't support the Vibration API, so this module
 * provides a native implementation that triggers haptic feedback.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/Vibration_API
 *
 * @module vibration
 */

import { bridge } from '../bridge';

/**
 * Vibration module for simple haptic feedback.
 * Aligned with the Web Vibration API (navigator.vibrate).
 *
 * Note: The Web Vibration API is not supported on iOS Safari.
 * This module provides a native polyfill using iOS haptics.
 *
 * @example
 * ```typescript
 * import { vibration } from '@eddmann/pwa-kit-sdk';
 *
 * // Simple vibration
 * vibration.vibrate(200);
 *
 * // Pattern vibration (vibrate, pause, vibrate)
 * vibration.vibrate([100, 50, 100]);
 *
 * // Stop vibration
 * vibration.vibrate(0);
 * ```
 */
export const vibration = {
  /**
   * Triggers device vibration.
   *
   * Aligned with navigator.vibrate().
   *
   * On iOS, this triggers haptic feedback since the Vibration API
   * is not supported. Single values trigger an impact haptic,
   * patterns trigger multiple haptics with the specified timing.
   *
   * @param pattern - Vibration duration in ms, or array of durations
   *                  for vibrate/pause pattern. Pass 0 or [] to stop.
   * @returns true if vibration was triggered, false otherwise
   */
  vibrate(pattern?: number | number[]): boolean {
    // Handle stop vibration
    if (pattern === 0 || (Array.isArray(pattern) && pattern.length === 0)) {
      return true; // Nothing to stop on iOS
    }

    // Normalize to array
    const durations = Array.isArray(pattern)
      ? pattern
      : pattern !== undefined
        ? [pattern]
        : [200]; // Default 200ms

    // Filter out zero durations and get vibration segments
    const vibrations = durations.filter((_, i) => i % 2 === 0).filter((d) => d > 0);

    // Trigger haptics for each vibration segment
    // We use a simple implementation that triggers one haptic per segment
    for (let i = 0; i < vibrations.length; i++) {
      // Use setTimeout to space out multiple vibrations
      const delay = durations.slice(0, i * 2).reduce((a, b) => a + b, 0);

      setTimeout(() => {
        // Trigger native haptic - fire and forget
        bridge.call('haptics', 'impact', { style: 'medium' }).catch(() => {
          // Ignore errors - vibrate() is fire-and-forget
        });
      }, delay);
    }

    return true;
  },
};
