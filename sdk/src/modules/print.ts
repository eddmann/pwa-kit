/**
 * Print Module API
 *
 * Provides AirPrint functionality for the current webview content.
 */

import { bridge } from '../bridge';

/**
 * Result from print operation.
 */
export interface PrintResult {
  /** Whether the print job was submitted */
  success: boolean;
  /** Error message if printing failed */
  error?: string;
}

/**
 * Print module for AirPrint functionality.
 *
 * @example
 * ```typescript
 * import { print } from '@pwa-kit/sdk';
 *
 * // Print the current page
 * const result = await print.print();
 * if (result.success) {
 *   console.log('Print job submitted');
 * }
 * ```
 */
export const print = {
  /**
   * Prints the current webview content using AirPrint.
   *
   * Opens the native print dialog, allowing the user to select
   * a printer and configure print options.
   *
   * @returns Print result
   */
  async print(): Promise<PrintResult> {
    return bridge.call<PrintResult>('print', 'print');
  },
};
