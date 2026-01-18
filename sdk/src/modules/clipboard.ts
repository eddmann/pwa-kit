/**
 * Clipboard Module API
 *
 * Provides clipboard read/write functionality.
 * Aligned with the Web Clipboard API.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
 *
 * @module clipboard
 */

import { bridge } from '../bridge';

/**
 * Result from clipboard read operation.
 */
export interface ClipboardReadResult {
  /** The clipboard text content, or null if empty */
  text: string | null;
}

/**
 * Clipboard module for text clipboard access.
 * Aligned with the Web Clipboard API (navigator.clipboard).
 *
 * Note: On iOS 16+, reading the clipboard may show a paste permission prompt.
 *
 * @example
 * ```typescript
 * import { clipboard } from '@eddmann/pwa-kit-sdk';
 *
 * // Copy text
 * await clipboard.writeText('Hello, World!');
 *
 * // Read text
 * const text = await clipboard.readText();
 * console.log('Clipboard contains:', text);
 * ```
 */
export const clipboard = {
  /**
   * Writes text to the clipboard.
   *
   * Aligned with navigator.clipboard.writeText().
   *
   * @param text - Text to copy to clipboard
   */
  async writeText(text: string): Promise<void> {
    await bridge.call('clipboard', 'write', { text });
  },

  /**
   * Reads text from the clipboard.
   *
   * Aligned with navigator.clipboard.readText().
   *
   * Note: On iOS 16+, this may trigger a paste permission prompt.
   *
   * @returns The clipboard text, or null if empty
   */
  async readText(): Promise<string | null> {
    const result = await bridge.call<ClipboardReadResult>('clipboard', 'read');
    return result.text;
  },
};
