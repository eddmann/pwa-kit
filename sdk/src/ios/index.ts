/**
 * iOS-Specific Modules
 *
 * Native iOS features that don't have web standard equivalents.
 * These are namespaced under `ios.*` to clearly indicate they are
 * platform-specific and won't work in regular browsers.
 *
 * @module ios
 *
 * @example
 * ```typescript
 * import { ios } from '@eddmann/pwa-kit-sdk';
 *
 * // Biometric authentication
 * await ios.biometrics.authenticate('Confirm payment');
 *
 * // Secure storage (Keychain)
 * await ios.secureStorage.set('token', 'secret');
 *
 * // HealthKit
 * await ios.healthKit.querySteps({ startDate, endDate });
 *
 * // In-app purchases
 * await ios.storeKit.purchase('premium');
 *
 * // App lifecycle
 * await ios.app.requestReview();
 *
 * // Local notifications (scheduling)
 * await ios.notifications.schedule({
 *   id: 'reminder',
 *   title: 'Reminder',
 *   trigger: { type: 'timeInterval', seconds: 60 }
 * });
 * ```
 */

export { biometrics } from './biometrics';
export type {
  BiometryType,
  BiometricAvailability,
  AuthenticationResult,
} from './biometrics';

export { secureStorage } from './secureStorage';
export type { GetResult } from './secureStorage';

export { healthKit } from './healthKit';
export type {
  QuantityType,
  WorkoutActivityType,
  SleepStage,
  HealthSample,
  WorkoutData,
  SleepSample,
  HealthKitAvailability,
  AuthorizationRequest,
  AuthorizationResult,
  QueryOptions,
  WorkoutQueryOptions,
} from './healthKit';

export { storeKit } from './storeKit';
export type {
  ProductType,
  ProductInfo,
  PurchaseResult,
  EntitlementInfo,
} from './storeKit';

export { app } from './app';
export type { AppVersion, ReviewResult } from './app';

export { notifications } from './notifications';
export type {
  TimeIntervalTrigger,
  DateTrigger,
  CalendarTrigger,
  NotificationTrigger,
  NotificationOptions,
  PendingNotification,
} from './notifications';
