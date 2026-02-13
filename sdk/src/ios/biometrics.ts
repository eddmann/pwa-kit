/**
 * Biometrics Module API
 *
 * Provides Face ID and Touch ID authentication via LocalAuthentication framework.
 *
 * @module ios/biometrics
 */

import { bridge } from '../bridge';

/**
 * Biometry types available on the device.
 */
export type BiometryType = 'none' | 'touchId' | 'faceId' | 'opticId';

/**
 * Result from checking biometric availability.
 */
export interface BiometricAvailability {
  /** Whether biometric authentication is available */
  available: boolean;
  /** The type of biometry available */
  biometryType: BiometryType;
  /** Error message if not available */
  error?: string;
}

/**
 * Result from biometric authentication.
 */
export interface AuthenticationResult {
  /** Whether authentication succeeded */
  success: boolean;
  /** Error message if authentication failed */
  error?: string;
}

/**
 * Biometrics module for Face ID and Touch ID authentication.
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Check availability
 * const availability = await ios.biometrics.isAvailable();
 * if (availability.available) {
 *   console.log(`${availability.biometryType} is available`);
 *
 *   // Authenticate
 *   const result = await ios.biometrics.authenticate('Access your account');
 *   if (result.success) {
 *     console.log('Authentication successful');
 *   } else {
 *     console.log('Authentication failed:', result.error);
 *   }
 * }
 * ```
 */
export const biometrics = {
  /**
   * Checks if biometric authentication is available.
   *
   * @returns Availability info including biometry type
   */
  async isAvailable(): Promise<BiometricAvailability> {
    return bridge.call<BiometricAvailability>('biometrics', 'isAvailable');
  },

  /**
   * Prompts the user for biometric authentication.
   *
   * @param reason - Localized reason displayed to the user
   * @returns Authentication result
   */
  async authenticate(reason: string): Promise<AuthenticationResult> {
    return bridge.call<AuthenticationResult>('biometrics', 'authenticate', {
      reason,
    });
  },
};
