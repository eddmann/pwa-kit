/**
 * Share Module API
 *
 * Provides native share sheet functionality via UIActivityViewController.
 */

import { bridge } from '../bridge';

/**
 * File data for sharing.
 */
export interface ShareFile {
  /** File name with extension */
  name: string;
  /** MIME type (e.g., 'image/png') */
  type: string;
  /** Base64 encoded file data */
  data: string;
}

/**
 * Options for sharing content.
 */
export interface ShareOptions {
  /** Share title (used as subject in some share targets) */
  title?: string;
  /** Text content to share */
  text?: string;
  /** URL to share */
  url?: string;
  /** Files to share (base64 encoded) */
  files?: ShareFile[];
}

/**
 * Result from sharing.
 */
export interface ShareResult {
  /** Whether the user completed the share action */
  completed: boolean;
  /** The activity type selected (if available) */
  activityType?: string;
}

/**
 * Share module for native share sheet functionality.
 *
 * @example
 * ```typescript
 * import { share } from '@pwa-kit/sdk';
 *
 * // Share a URL
 * const result = await share.share({
 *   title: 'Check this out',
 *   url: 'https://example.com'
 * });
 *
 * // Share text and URL
 * await share.share({
 *   text: 'Great article!',
 *   url: 'https://example.com/article'
 * });
 *
 * // Share a file
 * await share.share({
 *   files: [{
 *     name: 'image.png',
 *     type: 'image/png',
 *     data: 'base64encodeddata...'
 *   }]
 * });
 *
 * // Check if sharing is available
 * const canShare = await share.canShare();
 * ```
 */
export const share = {
  /**
   * Presents the native share sheet with the given content.
   *
   * @param options - Content to share
   * @returns Result indicating if the share was completed
   */
  async share(options: ShareOptions): Promise<ShareResult> {
    return bridge.call<ShareResult>('share', 'share', options);
  },

  /**
   * Checks if sharing is available.
   *
   * Always returns true on iOS native, but useful for graceful degradation
   * when running in regular browsers.
   *
   * @returns Whether the share API is available
   */
  async canShare(): Promise<boolean> {
    const result = await bridge.call<{ available: boolean }>(
      'share',
      'canShare'
    );
    return result.available;
  },
};
