/**
 * Secure Storage Module API
 *
 * Provides secure key-value storage using iOS Keychain.
 *
 * @module ios/secureStorage
 */

import { bridge } from '../bridge';

/**
 * Result from storage get operation.
 */
export interface GetResult {
  /** The stored value, or null if not found */
  value: string | null;
}

/**
 * Secure Storage module for Keychain-based storage.
 *
 * Values are stored securely in the iOS Keychain and persist
 * across app reinstalls (unless explicitly deleted).
 *
 * @example
 * ```typescript
 * import { ios } from '@eddmann/pwa-kit-sdk';
 *
 * // Store a value
 * await ios.secureStorage.set('auth_token', 'secret123');
 *
 * // Retrieve a value
 * const token = await ios.secureStorage.get('auth_token');
 * console.log('Token:', token);
 *
 * // Delete a value
 * await ios.secureStorage.delete('auth_token');
 *
 * // Check if a key exists
 * const exists = await ios.secureStorage.has('auth_token');
 * ```
 */
export const secureStorage = {
  /**
   * Stores a value in the Keychain.
   *
   * @param key - Storage key
   * @param value - Value to store
   */
  async set(key: string, value: string): Promise<void> {
    await bridge.call('secureStorage', 'set', { key, value });
  },

  /**
   * Retrieves a value from the Keychain.
   *
   * @param key - Storage key
   * @returns The stored value, or null if not found
   */
  async get(key: string): Promise<string | null> {
    const result = await bridge.call<GetResult>('secureStorage', 'get', { key });
    return result.value;
  },

  /**
   * Deletes a value from the Keychain.
   *
   * @param key - Storage key to delete
   */
  async delete(key: string): Promise<void> {
    await bridge.call('secureStorage', 'delete', { key });
  },

  /**
   * Checks if a key exists in the Keychain.
   *
   * @param key - Storage key to check
   * @returns Whether the key exists
   */
  async has(key: string): Promise<boolean> {
    const value = await this.get(key);
    return value !== null;
  },
};
