/**
 * PWAKit JavaScript SDK
 *
 * A TypeScript SDK for communicating with the PWAKit native iOS bridge.
 * Provides Web API-aligned interfaces for native capabilities.
 *
 * ## Web API-Aligned Modules
 *
 * These modules are aligned with Web Platform APIs:
 *
 * - `push` - Push notifications (PushManager)
 * - `badging` - App icon badges (Badging API)
 * - `vibration` - Vibration feedback (Vibration API)
 * - `clipboard` - Text clipboard (Clipboard API)
 * - `share` - Share content (Web Share API)
 * - `permissions` - Permission management (Permissions API)
 *
 * ## Enhanced APIs
 *
 * - `haptics` - iOS haptic feedback (impact, notification, selection)
 * - `print` - AirPrint functionality
 * - `platform` - Platform detection
 *
 * ## iOS-Specific Modules
 *
 * Namespaced under `ios.*` as they don't have web equivalents:
 *
 * - `ios.biometrics` - Face ID / Touch ID
 * - `ios.secureStorage` - Keychain storage
 * - `ios.healthKit` - HealthKit data
 * - `ios.storeKit` - In-app purchases
 * - `ios.app` - App lifecycle
 * - `ios.notifications` - Local notification scheduling
 *
 * @example
 * ```typescript
 * import {
 *   push,
 *   badging,
 *   clipboard,
 *   share,
 *   haptics,
 *   permissions,
 *   ios,
 *   isNative
 * } from '@eddmann/pwa-kit-sdk';
 *
 * if (isNative) {
 *   // Push notifications
 *   const subscription = await push.subscribe();
 *   console.log('Token:', subscription.token);
 *
 *   // Badges
 *   await badging.setAppBadge(5);
 *
 *   // Clipboard
 *   await clipboard.writeText('Hello');
 *
 *   // iOS-specific features
 *   await ios.biometrics.authenticate('Confirm');
 *   await ios.secureStorage.set('key', 'value');
 * }
 * ```
 *
 * @packageDocumentation
 */

// =============================================================================
// Core Bridge
// =============================================================================

export { PWABridge, bridge } from './bridge';
export type {
  BridgeMessage,
  BridgeResponse,
  BridgeEvent,
  BridgeCallOptions,
  BridgeConfig,
} from './bridge';
export {
  BridgeError,
  BridgeTimeoutError,
  BridgeUnavailableError,
} from './types';

// =============================================================================
// Web API-Aligned Modules
// =============================================================================

// Push API (PushManager)
export { push } from './modules/push';
export type {
  PushSubscription,
  PushPermissionState,
  PushNotificationData,
} from './modules/push';

// Badging API
export { badging } from './modules/badging';

// Vibration API
export { vibration } from './modules/vibration';

// Clipboard API
export { clipboard } from './modules/clipboard';
export type { ClipboardReadResult } from './modules/clipboard';

// Web Share API
export { share } from './modules/share';
export type { ShareFile, ShareOptions, ShareResult } from './modules/share';

// Permissions API
export { permissions } from './modules/permissions';
export type {
  PermissionName,
  PermissionState,
  PermissionStatus,
  PermissionDescriptor,
} from './modules/permissions';

// =============================================================================
// Enhanced APIs
// =============================================================================

// Haptics (iOS-enhanced vibration)
export { haptics } from './modules/haptics';
export type { ImpactStyle, NotificationType } from './modules/haptics';

// Print (enhanced window.print)
export { print } from './modules/print';
export type { PrintResult } from './modules/print';

// Platform detection
export { platform } from './modules/platform';
export type { PlatformInfo } from './modules/platform';

// =============================================================================
// iOS-Specific Modules (Namespaced)
// =============================================================================

export * as ios from './ios';

// Re-export iOS types for convenience
export type {
  BiometryType,
  BiometricAvailability,
  AuthenticationResult,
} from './ios/biometrics';

export type { GetResult as SecureStorageGetResult } from './ios/secureStorage';

export type {
  QuantityType,
  WorkoutActivityType,
  SleepStage,
  HealthSample,
  WorkoutData,
  SleepSample,
  HealthKitAvailability,
  AuthorizationRequest,
  AuthorizationResult as HealthKitAuthorizationResult,
  QueryOptions,
  WorkoutQueryOptions,
} from './ios/healthKit';

export type {
  ProductType,
  ProductInfo,
  PurchaseResult,
  EntitlementInfo,
} from './ios/storeKit';

export type { AppVersion, ReviewResult } from './ios/app';

export type {
  TimeIntervalTrigger,
  DateTrigger,
  CalendarTrigger,
  NotificationTrigger,
  NotificationOptions,
  PendingNotification,
} from './ios/notifications';

// =============================================================================
// Detection Utilities
// =============================================================================

export {
  isNative,
  platformInfo,
  hasMessageHandlers,
  hasPWAKitInUserAgent,
  detectPlatform,
  getUserAgent,
  getPlatformInfo,
} from './detection';
export type { Platform, PlatformDetectionInfo } from './detection';
