/**
 * Live Activity (Dynamic Island) Module API
 *
 * Provides control over iOS Live Activities displayed in the Dynamic Island
 * (iPhone 14 Pro and later) and on the Lock Screen. Requires iOS 16.1+.
 *
 * @module ios/liveActivity
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Check if Live Activities are enabled
 * const { enabled } = await ios.liveActivity.areActivitiesEnabled();
 *
 * // Start a delivery tracking activity
 * const result = await ios.liveActivity.start({
 *   activityId: 'delivery-123',
 *   title: 'Order #1234',
 *   subtitle: 'Preparing your food',
 *   progress: 0.3,
 *   icon: 'fork.knife',
 *   tint: '#FF6B35',
 *   fields: { eta: '12:30 PM', status: 'Cooking' }
 * });
 *
 * // Update progress
 * await ios.liveActivity.update({
 *   title: 'Order #1234',
 *   subtitle: 'On the way!',
 *   progress: 0.75,
 *   icon: 'car.fill',
 *   fields: { eta: '12:15 PM', status: 'Delivering' }
 * });
 *
 * // End the activity
 * await ios.liveActivity.end({ dismissalPolicy: 'default' });
 * ```
 */

import { bridge } from '../bridge';

/**
 * Options for starting or updating a Live Activity.
 */
export interface LiveActivityOptions {
  /** Primary title displayed in the Dynamic Island expanded view */
  title: string;
  /** Subtitle displayed below the title */
  subtitle?: string;
  /** Progress value between 0.0 and 1.0 */
  progress?: number;
  /** SF Symbol name for the activity icon */
  icon?: string;
  /** Hex color string for the accent/tint color (e.g., '#FF6B35') */
  tint?: string;
  /** Arbitrary key-value pairs for custom display fields */
  fields?: Record<string, string>;
}

/**
 * Options for starting a Live Activity, including an optional identifier.
 */
export interface LiveActivityStartOptions extends LiveActivityOptions {
  /** Unique identifier for this activity type (default: 'pwakit-activity') */
  activityId?: string;
}

/**
 * Result from starting a Live Activity.
 */
export interface LiveActivityStartResult {
  /** Whether the activity was started successfully */
  started: boolean;
  /** The system-assigned activity ID (if started) */
  id?: string;
  /** Reason the activity could not be started */
  reason?: string;
  /** ActivityKit push token for server-side updates (iOS 16.2+) */
  pushToken?: string;
}

/**
 * Result from getting the ActivityKit push token.
 */
export interface LiveActivityPushTokenResult {
  /** The push token as a hex string, or null if not available */
  token: string | null;
  /** Reason the token is unavailable */
  reason?: string;
}

/**
 * Result from updating a Live Activity.
 */
export interface LiveActivityUpdateResult {
  /** Whether the update was applied */
  updated: boolean;
}

/**
 * Options for ending a Live Activity.
 */
export interface LiveActivityEndOptions {
  /** How the activity should be dismissed: 'default' keeps it briefly, 'immediate' removes it */
  dismissalPolicy?: 'default' | 'immediate';
}

/**
 * Result from ending a Live Activity.
 */
export interface LiveActivityEndResult {
  /** Whether all activities were ended */
  ended: boolean;
}

/**
 * Current state of Live Activities.
 */
export interface LiveActivityState {
  /** Whether there is an active Live Activity */
  active: boolean;
  /** Number of active Live Activities */
  count: number;
  /** System ID of the first active activity */
  id?: string;
  /** Current title of the first active activity */
  title?: string;
  /** Current subtitle of the first active activity */
  subtitle?: string;
  /** Current progress of the first active activity */
  progress?: number;
}

/**
 * Result from checking if Live Activities are enabled.
 */
export interface LiveActivityEnabledResult {
  /** Whether Live Activities are enabled in device settings */
  enabled: boolean;
}

/**
 * Live Activity module for controlling Dynamic Island and Lock Screen
 * Live Activities from a PWA.
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Start a timer activity
 * await ios.liveActivity.start({
 *   title: 'Workout Timer',
 *   subtitle: '30:00 remaining',
 *   progress: 0.0,
 *   icon: 'timer',
 *   tint: '#FF3B30'
 * });
 *
 * // Check current state
 * const state = await ios.liveActivity.getState();
 * if (state.active) {
 *   console.log(`Active: ${state.title}`);
 * }
 * ```
 */
export const liveActivity = {
  /**
   * Starts a new Live Activity displayed in the Dynamic Island and Lock Screen.
   *
   * @param options - Activity content and configuration
   * @returns Result indicating success and the activity ID
   */
  async start(options: LiveActivityStartOptions): Promise<LiveActivityStartResult> {
    return bridge.call<LiveActivityStartResult>('liveActivity', 'start', options);
  },

  /**
   * Updates the content of all active Live Activities.
   *
   * @param options - New content to display
   * @returns Result indicating the update was applied
   */
  async update(options: LiveActivityOptions): Promise<LiveActivityUpdateResult> {
    return bridge.call<LiveActivityUpdateResult>('liveActivity', 'update', options);
  },

  /**
   * Ends all active Live Activities.
   *
   * @param options - Optional dismissal configuration
   * @returns Result indicating activities were ended
   */
  async end(options?: LiveActivityEndOptions): Promise<LiveActivityEndResult> {
    return bridge.call<LiveActivityEndResult>('liveActivity', 'end', options);
  },

  /**
   * Gets the current state of Live Activities.
   *
   * @returns Current activity state including count and content
   */
  async getState(): Promise<LiveActivityState> {
    return bridge.call<LiveActivityState>('liveActivity', 'getState');
  },

  /**
   * Checks if Live Activities are enabled on this device.
   *
   * Users can disable Live Activities in Settings > Face ID & Passcode.
   *
   * @returns Whether Live Activities are enabled
   */
  async areActivitiesEnabled(): Promise<LiveActivityEnabledResult> {
    return bridge.call<LiveActivityEnabledResult>('liveActivity', 'areActivitiesEnabled');
  },

  /**
   * Gets the ActivityKit push token for server-side background updates.
   *
   * After starting a Live Activity, call this to get the push token that your
   * server needs to send updates to Apple's push service (api.push.apple.com).
   * This enables the Dynamic Island to update without waking the app.
   *
   * Requires iOS 16.2+. Returns null on older versions.
   *
   * @returns The push token or null if unavailable
   *
   * @example
   * ```typescript
   * const { started, pushToken } = await ios.liveActivity.start({
   *   title: 'Order #1234',
   *   subtitle: 'Preparing'
   * });
   *
   * // Token may not be available immediately after start
   * if (!pushToken) {
   *   const { token } = await ios.liveActivity.getPushToken();
   *   if (token) {
   *     await sendTokenToServer(token);
   *   }
   * }
   * ```
   */
  async getPushToken(): Promise<LiveActivityPushTokenResult> {
    return bridge.call<LiveActivityPushTokenResult>('liveActivity', 'getPushToken');
  },
};
