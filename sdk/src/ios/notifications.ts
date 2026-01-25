/**
 * Notifications Module API
 *
 * Provides local notification scheduling capabilities.
 * Extends the push notification functionality with local notifications.
 *
 * @module notifications
 */

import { bridge } from '../bridge';

// =============================================================================
// Trigger Types
// =============================================================================

/**
 * Trigger notification after a time interval.
 */
export interface TimeIntervalTrigger {
  type: 'timeInterval';
  /** Number of seconds until the notification fires. */
  seconds: number;
  /** Whether to repeat. If true, minimum interval is 60 seconds. */
  repeats?: boolean;
}

/**
 * Trigger notification at a specific date.
 */
export interface DateTrigger {
  type: 'date';
  /** The date when the notification should fire (ISO 8601 string or Date object). */
  date: Date | string;
}

/**
 * Trigger notification based on calendar components.
 */
export interface CalendarTrigger {
  type: 'calendar';
  /** Hour of the day (0-23). */
  hour?: number;
  /** Minute of the hour (0-59). */
  minute?: number;
  /** Second of the minute (0-59). */
  second?: number;
  /** Day of the week (1 = Sunday, 7 = Saturday). */
  weekday?: number;
  /** Day of the month (1-31). */
  day?: number;
  /** Month of the year (1-12). */
  month?: number;
  /** Year. */
  year?: number;
  /** Whether to repeat at this time. */
  repeats?: boolean;
}

/**
 * Union of all trigger types.
 */
export type NotificationTrigger =
  | TimeIntervalTrigger
  | DateTrigger
  | CalendarTrigger;

// =============================================================================
// Notification Options
// =============================================================================

/**
 * Options for scheduling a local notification.
 */
export interface NotificationOptions {
  /** Unique identifier for the notification. */
  id: string;
  /** The notification title. */
  title: string;
  /** The notification body text. */
  body?: string;
  /** The notification subtitle. */
  subtitle?: string;
  /** The badge count to display on the app icon. */
  badge?: number;
  /** The sound to play. Use 'default' for the default sound, or a custom sound name. */
  sound?: 'default' | string;
  /** Custom data to include with the notification. */
  data?: Record<string, unknown>;
  /** When to trigger the notification. */
  trigger: NotificationTrigger;
}

// =============================================================================
// Pending Notification Info
// =============================================================================

/**
 * Information about a pending scheduled notification.
 */
export interface PendingNotification {
  /** The notification identifier. */
  id: string;
  /** The notification title. */
  title: string;
  /** The notification body. */
  body?: string;
  /** The notification subtitle. */
  subtitle?: string;
  /** Whether the notification repeats. */
  repeats: boolean;
  /** The next trigger date (ISO 8601 string), if determinable. */
  nextTriggerDate?: string;
}

// =============================================================================
// Internal Types
// =============================================================================

interface ScheduleResult {
  success: boolean;
  id: string;
}

interface SuccessResult {
  success: boolean;
}

interface PendingResult {
  notifications: PendingNotification[];
}

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Converts a trigger to the format expected by the native bridge.
 */
function serializeTrigger(trigger: NotificationTrigger): Record<string, unknown> {
  if (trigger.type === 'date') {
    const date = trigger.date instanceof Date
      ? trigger.date.toISOString()
      : trigger.date;
    return { type: 'date', date };
  }
  // Spread the trigger object to convert to a plain object
  return { ...trigger };
}

// =============================================================================
// Notifications Module
// =============================================================================

/**
 * Notifications module for scheduling local notifications.
 *
 * @example
 * ```typescript
 * import { notifications } from '@eddmann/pwa-kit-sdk';
 *
 * // Schedule a one-off notification in 60 seconds
 * await notifications.schedule({
 *   id: 'reminder',
 *   title: 'Reminder',
 *   body: 'Check this out!',
 *   trigger: { type: 'timeInterval', seconds: 60 }
 * });
 *
 * // Schedule a daily notification at 9 AM
 * await notifications.schedule({
 *   id: 'daily',
 *   title: 'Good morning!',
 *   trigger: { type: 'calendar', hour: 9, minute: 0, repeats: true }
 * });
 *
 * // Schedule a notification for a specific date
 * await notifications.schedule({
 *   id: 'meeting',
 *   title: 'Meeting starts',
 *   trigger: { type: 'date', date: new Date('2024-12-25T10:00:00') }
 * });
 *
 * // Cancel a specific notification
 * await notifications.cancel('reminder');
 *
 * // Cancel all notifications
 * await notifications.cancelAll();
 *
 * // Get all pending notifications
 * const pending = await notifications.getPending();
 * console.log(pending);
 * ```
 */
export const notifications = {
  /**
   * Schedules a local notification.
   *
   * @param options - The notification options including trigger.
   * @returns The scheduled notification ID.
   * @throws Error if scheduling fails.
   *
   * @example
   * ```typescript
   * // One-off notification in 5 minutes
   * await notifications.schedule({
   *   id: 'reminder-123',
   *   title: 'Time to take a break',
   *   body: 'You have been working for an hour',
   *   trigger: { type: 'timeInterval', seconds: 300 }
   * });
   *
   * // Repeating notification every hour (minimum 60 seconds for repeating)
   * await notifications.schedule({
   *   id: 'hourly',
   *   title: 'Hourly check-in',
   *   trigger: { type: 'timeInterval', seconds: 3600, repeats: true }
   * });
   * ```
   */
  async schedule(options: NotificationOptions): Promise<string> {
    const payload = {
      id: options.id,
      title: options.title,
      body: options.body,
      subtitle: options.subtitle,
      badge: options.badge,
      sound: options.sound,
      data: options.data,
      trigger: serializeTrigger(options.trigger),
    };

    const result = await bridge.call<ScheduleResult>(
      'notifications',
      'schedule',
      payload
    );

    if (!result.success) {
      throw new Error('Failed to schedule notification');
    }

    return result.id;
  },

  /**
   * Cancels a scheduled notification by ID.
   *
   * @param id - The notification identifier to cancel.
   *
   * @example
   * ```typescript
   * await notifications.cancel('reminder-123');
   * ```
   */
  async cancel(id: string): Promise<void> {
    await bridge.call<SuccessResult>('notifications', 'cancel', { id });
  },

  /**
   * Cancels all scheduled notifications.
   *
   * @example
   * ```typescript
   * await notifications.cancelAll();
   * ```
   */
  async cancelAll(): Promise<void> {
    await bridge.call<SuccessResult>('notifications', 'cancelAll');
  },

  /**
   * Gets all pending scheduled notifications.
   *
   * @returns Array of pending notification information.
   *
   * @example
   * ```typescript
   * const pending = await notifications.getPending();
   * for (const notification of pending) {
   *   console.log(`${notification.id}: ${notification.title}`);
   *   if (notification.nextTriggerDate) {
   *     console.log(`  Next: ${notification.nextTriggerDate}`);
   *   }
   * }
   * ```
   */
  async getPending(): Promise<PendingNotification[]> {
    const result = await bridge.call<PendingResult>(
      'notifications',
      'getPending'
    );
    return result.notifications;
  },
};
