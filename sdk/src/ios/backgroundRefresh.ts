/**
 * Background Refresh Module API
 *
 * Configures periodic background data fetching to keep widgets up to date.
 * iOS periodically wakes the app via BGTaskScheduler to fetch fresh data
 * from the configured URL, then updates widgets with the response.
 *
 * @module ios/backgroundRefresh
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Configure the URL that iOS will fetch in the background
 * await ios.backgroundRefresh.configureUrl('https://api.example.com/widget-data');
 *
 * // Check refresh status
 * const status = await ios.backgroundRefresh.getStatus();
 * console.log('Last refresh:', new Date(status.lastRefresh * 1000));
 * ```
 *
 * The refresh URL should return JSON in this format:
 * ```json
 * {
 *   "widgets": [
 *     { "kind": "status", "title": "Steps", "value": "9,200" }
 *   ],
 *   "liveActivity": {
 *     "title": "Order #1234",
 *     "subtitle": "On the way!",
 *     "progress": 0.75
 *   }
 * }
 * ```
 */

import { bridge } from '../bridge';

/**
 * Result from configuring the refresh URL.
 */
export interface BackgroundRefreshConfigResult {
  /** Whether the URL was configured successfully */
  configured: boolean;
  /** The configured URL */
  url: string;
}

/**
 * Result from removing the refresh URL.
 */
export interface BackgroundRefreshRemoveResult {
  /** Whether the URL was removed */
  removed: boolean;
}

/**
 * Current status of background refresh.
 */
export interface BackgroundRefreshStatus {
  /** Whether a refresh URL is configured */
  configured: boolean;
  /** The configured URL, if any */
  url?: string;
  /** Timestamp (seconds since epoch) of the last successful refresh */
  lastRefresh?: number;
}

/**
 * Result from scheduling a refresh.
 */
export interface BackgroundRefreshScheduleResult {
  /** Whether the refresh was scheduled */
  scheduled: boolean;
}

/**
 * Background refresh module for keeping widget data up to date.
 *
 * Configures a URL that iOS fetches periodically in the background
 * to update widget content without user interaction.
 */
export const backgroundRefresh = {
  /**
   * Configures the URL to fetch during background refresh.
   *
   * iOS will periodically fetch this URL and use the response to update
   * widget data. The URL must return JSON matching the expected format.
   *
   * Also schedules the first background refresh automatically.
   *
   * @param url - The HTTPS URL to fetch for widget data updates
   * @returns Result confirming the URL was configured
   */
  async configureUrl(url: string): Promise<BackgroundRefreshConfigResult> {
    return bridge.call<BackgroundRefreshConfigResult>('backgroundRefresh', 'configureUrl', {
      url,
    });
  },

  /**
   * Removes the configured refresh URL.
   *
   * Background refreshes will stop after the URL is removed.
   *
   * @returns Result confirming the URL was removed
   */
  async removeUrl(): Promise<BackgroundRefreshRemoveResult> {
    return bridge.call<BackgroundRefreshRemoveResult>('backgroundRefresh', 'removeUrl');
  },

  /**
   * Gets the current background refresh status.
   *
   * @returns Status including configured URL and last refresh timestamp
   */
  async getStatus(): Promise<BackgroundRefreshStatus> {
    return bridge.call<BackgroundRefreshStatus>('backgroundRefresh', 'getStatus');
  },

  /**
   * Manually schedules the next background refresh.
   *
   * iOS determines the actual timing (minimum 15 minutes from now).
   *
   * @returns Result confirming the refresh was scheduled
   */
  async scheduleRefresh(): Promise<BackgroundRefreshScheduleResult> {
    return bridge.call<BackgroundRefreshScheduleResult>('backgroundRefresh', 'scheduleRefresh');
  },
};
