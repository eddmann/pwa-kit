/**
 * Platform Module API
 *
 * Provides platform detection and device information.
 */

import { bridge } from '../bridge';

/**
 * Platform information returned by getInfo().
 */
export interface PlatformInfo {
  /** Platform identifier (e.g., 'ios') */
  platform: string;
  /** OS version (e.g., '17.0') */
  version: string;
  /** Whether running in native app wrapper */
  isNative: boolean;
  /** App version string */
  appVersion: string;
  /** App build number */
  buildNumber: string;
  /** Device model (e.g., 'iPhone15,2') */
  deviceModel: string;
  /** PWAKit framework version (e.g., '0.1.0') */
  pwaKitVersion: string;
}

/**
 * Platform module for native platform detection and info.
 *
 * @example
 * ```typescript
 * import { platform } from '@eddmann/pwa-kit-sdk';
 *
 * const info = await platform.getInfo();
 * console.log(`Running on ${info.platform} ${info.version}`);
 * console.log(`App version: ${info.appVersion}`);
 * ```
 */
export const platform = {
  /**
   * Gets platform and device information.
   *
   * @returns Platform information including OS version, app version, and device model
   */
  async getInfo(): Promise<PlatformInfo> {
    return bridge.call<PlatformInfo>('platform', 'getInfo');
  },
};
