/**
 * Widget Module API
 *
 * Provides control over iOS Lock Screen and Home Screen widgets.
 * Data is pushed to the widget through a shared App Group container,
 * and WidgetKit timelines are reloaded to reflect changes.
 *
 * @module ios/widget
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Update a status widget
 * await ios.widget.update({
 *   kind: 'status',
 *   title: 'Steps Today',
 *   value: '8,421',
 *   subtitle: 'Goal: 10,000',
 *   icon: 'figure.walk',
 *   tint: '#34C759',
 *   url: 'https://app.example.com/steps'
 * });
 *
 * // Remove widget data
 * await ios.widget.remove('status');
 *
 * // Force reload all widgets
 * await ios.widget.reloadAll();
 * ```
 */

import { bridge } from '../bridge';

/**
 * Data to display in a widget.
 */
export interface WidgetData {
  /** Widget kind identifier matching a registered widget type */
  kind: string;
  /** Primary title for the widget */
  title: string;
  /** Primary display value (shown as large text) */
  value?: string;
  /** Subtitle displayed below the value */
  subtitle?: string;
  /** SF Symbol name for the widget icon */
  icon?: string;
  /** Hex color string for the accent color (e.g., '#34C759') */
  tint?: string;
  /** Deep link URL opened when the widget is tapped */
  url?: string;
}

/**
 * Result from updating widget data.
 */
export interface WidgetUpdateResult {
  /** Whether the update was applied */
  updated: boolean;
  /** The widget kind that was updated */
  kind: string;
}

/**
 * Result from removing widget data.
 */
export interface WidgetRemoveResult {
  /** Whether the data was removed */
  removed: boolean;
  /** The widget kind that was removed */
  kind: string;
}

/**
 * Result from reloading all widget timelines.
 */
export interface WidgetReloadResult {
  /** Whether timelines were reloaded */
  reloaded: boolean;
}

/**
 * Result from getting available widget kinds.
 */
export interface WidgetKindsResult {
  /** Array of registered widget kind identifiers */
  kinds: string[];
}

/**
 * Widget module for controlling Lock Screen and Home Screen widgets
 * from a PWA.
 *
 * Widgets display read-only snapshots of your app's data. Call `update()`
 * whenever your data changes, and the widget will refresh to show the
 * latest content.
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Show a compact weather widget
 * await ios.widget.update({
 *   kind: 'compact',
 *   title: 'Weather',
 *   value: '72°F',
 *   subtitle: 'Sunny',
 *   icon: 'sun.max.fill',
 *   tint: '#FF9500'
 * });
 *
 * // List available widget kinds
 * const { kinds } = await ios.widget.getKinds();
 * console.log('Available widgets:', kinds);
 * ```
 */
export const widget = {
  /**
   * Updates widget content and triggers a timeline reload.
   *
   * The data is written to the shared App Group container and the
   * corresponding widget timeline is reloaded.
   *
   * @param data - Widget content to display
   * @returns Result indicating the update was applied
   */
  async update(data: WidgetData): Promise<WidgetUpdateResult> {
    return bridge.call<WidgetUpdateResult>('widget', 'update', data);
  },

  /**
   * Removes widget data for a specific kind.
   *
   * Clears the stored data and triggers a timeline reload, causing
   * the widget to show its placeholder/empty state.
   *
   * @param kind - Widget kind identifier to remove
   * @returns Result indicating the data was removed
   */
  async remove(kind: string): Promise<WidgetRemoveResult> {
    return bridge.call<WidgetRemoveResult>('widget', 'remove', { kind });
  },

  /**
   * Forces a reload of all widget timelines.
   *
   * Use sparingly — WidgetKit manages reload frequency. Prefer
   * `update()` which reloads only the specific widget kind.
   *
   * @returns Result indicating timelines were reloaded
   */
  async reloadAll(): Promise<WidgetReloadResult> {
    return bridge.call<WidgetReloadResult>('widget', 'reloadAll');
  },

  /**
   * Gets the list of available widget kinds.
   *
   * Returns the widget kind identifiers registered by the Widget Extension.
   *
   * @returns Available widget kinds
   */
  async getKinds(): Promise<WidgetKindsResult> {
    return bridge.call<WidgetKindsResult>('widget', 'getKinds');
  },
};
