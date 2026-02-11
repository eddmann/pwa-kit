/**
 * Push Module API
 *
 * Provides push notification registration via APNs.
 * Aligned with the Web Push API (PushManager).
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/PushManager
 *
 * @module push
 */

import { bridge } from '../bridge';

/**
 * Push subscription containing the device token.
 * Aligned with Web Push API's PushSubscription.
 */
export interface PushSubscription {
  /** The APNs device token (hex string) */
  token: string;
  /** Endpoint URL (for compatibility, maps to token) */
  endpoint: string;
}

/**
 * Push permission states aligned with Web Permissions API.
 */
export type PushPermissionState = 'granted' | 'denied' | 'prompt';

/**
 * Push notification data received via events.
 */
export interface PushNotificationData {
  /** Notification title */
  title?: string;
  /** Notification body */
  body?: string;
  /** Badge count */
  badge?: number;
  /** Sound name */
  sound?: string;
  /** Custom user info payload */
  data?: Record<string, unknown>;
}

/**
 * Internal result from native subscribe call.
 */
interface SubscribeResult {
  success: boolean;
  token?: string;
  error?: string;
}

/**
 * Internal permission state result.
 *
 * The native side sends NotificationPermissionState raw values:
 * - "not_determined" (not yet asked)
 * - "denied"
 * - "granted"
 * - "unavailable"
 * - "unknown"
 */
interface PermissionStateResult {
  state: string;
}

/**
 * Maps native permission states to Web API states.
 */
function mapPermissionState(state: string): PushPermissionState {
  switch (state) {
    case 'granted':
      return 'granted';
    case 'denied':
      return 'denied';
    case 'not_determined':
    default:
      return 'prompt';
  }
}

/**
 * Push module for push notification registration.
 * Aligned with the Web Push API (PushManager).
 *
 * @example
 * ```typescript
 * import { push } from '@eddmann/pwa-kit-sdk';
 *
 * // Subscribe to push notifications
 * const subscription = await push.subscribe();
 * console.log('Token:', subscription.token);
 * // Send token to your server
 *
 * // Check permission state
 * const state = await push.permissionState();
 * if (state === 'prompt') {
 *   // Can request permission
 * }
 *
 * // Get existing subscription
 * const existing = await push.getSubscription();
 * if (existing) {
 *   console.log('Already subscribed:', existing.token);
 * }
 * ```
 */
export const push = {
  /**
   * Subscribes to push notifications.
   *
   * Requests notification permission if needed, then registers for
   * remote notifications with APNs.
   *
   * Aligned with PushManager.subscribe().
   *
   * @returns Push subscription with device token
   * @throws Error if subscription fails
   */
  async subscribe(): Promise<PushSubscription> {
    const result = await bridge.call<SubscribeResult>(
      'notifications',
      'subscribe'
    );

    if (!result.success || !result.token) {
      throw new Error(result.error ?? 'Failed to subscribe to push notifications');
    }

    return {
      token: result.token,
      endpoint: `apns://${result.token}`,
    };
  },

  /**
   * Gets the current push subscription if one exists.
   *
   * Aligned with PushManager.getSubscription().
   *
   * @returns The current subscription, or null if not subscribed
   */
  async getSubscription(): Promise<PushSubscription | null> {
    const result = await bridge.call<{ token: string | null }>(
      'notifications',
      'getToken'
    );

    if (!result.token) {
      return null;
    }

    return {
      token: result.token,
      endpoint: `apns://${result.token}`,
    };
  },

  /**
   * Requests notification permission without registering for push.
   *
   * Use this when you only need local notifications and don't need
   * an APNs device token. Aligned with Notification.requestPermission().
   *
   * @returns Permission state after the request: 'granted', 'denied', or 'prompt'
   */
  async requestPermission(): Promise<PushPermissionState> {
    const result = await bridge.call<{ granted: boolean; state: string }>(
      'notifications',
      'requestPermission'
    );

    return mapPermissionState(result.state as PermissionStateResult['state']);
  },

  /**
   * Gets the current push notification permission state.
   *
   * Aligned with PushManager.permissionState().
   *
   * @returns Permission state: 'granted', 'denied', or 'prompt'
   */
  async permissionState(): Promise<PushPermissionState> {
    const result = await bridge.call<PermissionStateResult>(
      'notifications',
      'getPermissionState'
    );

    return mapPermissionState(result.state);
  },
};
