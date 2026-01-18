/**
 * Haptics Module API
 *
 * Provides haptic feedback using native iOS haptic engine.
 */

import { bridge } from '../bridge';

/**
 * Impact feedback styles matching UIImpactFeedbackGenerator.FeedbackStyle.
 */
export type ImpactStyle = 'light' | 'medium' | 'heavy' | 'soft' | 'rigid';

/**
 * Notification feedback types matching UINotificationFeedbackGenerator.FeedbackType.
 */
export type NotificationType = 'success' | 'warning' | 'error';

/**
 * Haptics module for native haptic feedback.
 *
 * @example
 * ```typescript
 * import { haptics } from '@eddmann/pwa-kit-sdk';
 *
 * // Trigger impact feedback
 * await haptics.impact('medium');
 *
 * // Trigger notification feedback
 * await haptics.notification('success');
 *
 * // Trigger selection feedback
 * await haptics.selection();
 * ```
 */
export const haptics = {
  /**
   * Triggers impact haptic feedback.
   *
   * Use for button taps, toggles, and physical interactions.
   *
   * @param style - The impact style (default: 'medium')
   */
  async impact(style: ImpactStyle = 'medium'): Promise<void> {
    await bridge.call('haptics', 'impact', { style });
  },

  /**
   * Triggers notification haptic feedback.
   *
   * Use for success/warning/error outcomes.
   *
   * @param type - The notification type (default: 'success')
   */
  async notification(type: NotificationType = 'success'): Promise<void> {
    await bridge.call('haptics', 'notification', { type });
  },

  /**
   * Triggers selection haptic feedback.
   *
   * Use for selection changes in pickers, sliders, etc.
   */
  async selection(): Promise<void> {
    await bridge.call('haptics', 'selection');
  },
};
