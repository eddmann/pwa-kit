/**
 * HealthKit Module API
 *
 * Provides access to health and fitness data via Apple HealthKit.
 *
 * @module ios/healthKit
 */

import { bridge } from '../bridge';

/**
 * Supported HealthKit quantity types.
 *
 * These map to Apple HealthKit HKQuantityTypeIdentifier values.
 */
export type QuantityType =
  // Activity
  | 'stepCount'
  | 'distanceWalkingRunning'
  | 'distanceCycling'
  | 'distanceSwimming'
  | 'flightsClimbed'
  | 'activeEnergyBurned'
  | 'basalEnergyBurned'
  // Heart
  | 'heartRate'
  | 'restingHeartRate'
  | 'walkingHeartRateAverage'
  | 'heartRateVariability'
  // Body
  | 'bodyMass'
  | 'bodyMassIndex'
  | 'height'
  | 'bodyTemperature'
  // Vitals
  | 'oxygenSaturation'
  | 'respiratoryRate'
  | 'bloodPressureSystolic'
  | 'bloodPressureDiastolic'
  | 'bloodGlucose'
  // Nutrition
  | 'dietaryWater'
  | 'dietaryCaffeine';

/**
 * Supported workout activity types.
 *
 * These map to Apple HealthKit HKWorkoutActivityType values.
 */
export type WorkoutActivityType =
  // Cardio
  | 'running'
  | 'walking'
  | 'cycling'
  | 'swimming'
  | 'hiking'
  | 'elliptical'
  | 'rowing'
  | 'stairClimbing'
  | 'crossTraining'
  | 'mixedCardio'
  // High Intensity
  | 'hiit'
  // Strength & Flexibility
  | 'yoga'
  | 'pilates'
  | 'dance'
  | 'coreTraining'
  | 'strengthTraining'
  | 'functionalStrengthTraining'
  | 'traditionalStrengthTraining'
  // Other
  | 'other';

/**
 * Sleep analysis stages.
 */
export type SleepStage =
  | 'inBed'
  | 'asleepUnspecified'
  | 'awake'
  | 'asleepCore'
  | 'asleepDeep'
  | 'asleepREM';

/**
 * Health sample data point.
 */
export interface HealthSample {
  /** Sample value */
  value: number;
  /** Unit of measurement (e.g., 'count', 'bpm', 'kcal') */
  unit: string;
  /** Sample start date (ISO 8601) */
  startDate: string;
  /** Sample end date (ISO 8601) */
  endDate: string;
  /** Data source name */
  sourceName?: string;
}

/**
 * Workout data.
 */
export interface WorkoutData {
  /** Workout activity type */
  type: WorkoutActivityType;
  /** Workout duration in seconds */
  duration: number;
  /** Calories burned (kcal) */
  calories?: number;
  /** Distance covered (meters) */
  distance?: number;
  /** Start date (ISO 8601) */
  startDate: string;
  /** End date (ISO 8601) */
  endDate: string;
}

/**
 * Sleep sample data.
 */
export interface SleepSample {
  /** Sleep stage */
  stage: SleepStage;
  /** Sample start date (ISO 8601) */
  startDate: string;
  /** Sample end date (ISO 8601) */
  endDate: string;
}

/**
 * HealthKit availability result.
 */
export interface HealthKitAvailability {
  /** Whether HealthKit is available on this device */
  available: boolean;
}

/**
 * Authorization request types.
 */
export interface AuthorizationRequest {
  /** Types to request read permission for */
  read?: QuantityType[];
  /** Types to request write permission for */
  write?: QuantityType[];
  /** Request workout read access */
  readWorkouts?: boolean;
  /** Request workout write access */
  writeWorkouts?: boolean;
  /** Request sleep read access */
  readSleep?: boolean;
}

/**
 * Authorization result.
 */
export interface AuthorizationResult {
  /** Whether authorization was granted */
  success: boolean;
  /** Error message if failed */
  error?: string;
}

/**
 * Query options for health data.
 */
export interface QueryOptions {
  /** Start date (ISO 8601) */
  startDate: string;
  /** End date (ISO 8601) */
  endDate: string;
  /** Maximum number of results to return */
  limit?: number;
}

/**
 * Workout query options.
 */
export interface WorkoutQueryOptions extends QueryOptions {
  /** Filter by activity type */
  type?: WorkoutActivityType;
}

/**
 * Request to save a workout to HealthKit.
 */
export interface SaveWorkoutRequest {
  /** Workout activity type */
  workoutType: WorkoutActivityType;
  /** Start date (ISO 8601) */
  startDate: string;
  /** End date (ISO 8601) */
  endDate: string;
  /** Calories burned (kcal) */
  calories?: number;
  /** Distance covered (meters) */
  distance?: number;
}

/**
 * HealthKit module for health and fitness data access.
 *
 * Note: Requires HealthKit entitlement and proper Info.plist usage descriptions.
 * HealthKit is not available in the iOS Simulator.
 *
 * @example
 * ```typescript
 * import { ios } from '@pwa-kit/sdk';
 *
 * // Check availability
 * const { available } = await ios.healthKit.isAvailable();
 * if (!available) {
 *   console.log('HealthKit not available');
 *   return;
 * }
 *
 * // Request authorization
 * const auth = await ios.healthKit.requestAuthorization({
 *   read: ['stepCount', 'heartRate'],
 *   readWorkouts: true
 * });
 *
 * if (auth.success) {
 *   // Query steps
 *   const steps = await ios.healthKit.querySteps({
 *     startDate: '2024-01-01T00:00:00Z',
 *     endDate: '2024-01-02T00:00:00Z'
 *   });
 *   console.log('Steps:', steps);
 * }
 * ```
 */
export const healthKit = {
  /**
   * Checks if HealthKit is available on this device.
   *
   * @returns Availability result
   */
  async isAvailable(): Promise<HealthKitAvailability> {
    return bridge.call<HealthKitAvailability>('healthkit', 'isAvailable');
  },

  /**
   * Requests HealthKit authorization for the specified data types.
   *
   * @param request - Authorization request specifying read/write types
   * @returns Authorization result
   */
  async requestAuthorization(
    request: AuthorizationRequest
  ): Promise<AuthorizationResult> {
    return bridge.call<AuthorizationResult>(
      'healthkit',
      'requestAuthorization',
      request
    );
  },

  /**
   * Queries step count data.
   *
   * @param options - Query options with date range
   * @returns Array of step count samples
   */
  async querySteps(options: QueryOptions): Promise<HealthSample[]> {
    const result = await bridge.call<{ samples: HealthSample[] }>(
      'healthkit',
      'querySteps',
      options
    );
    return result.samples;
  },

  /**
   * Queries the total deduplicated step count for a date range.
   *
   * Unlike `querySteps` which returns raw samples (which may overlap across
   * sources like iPhone + Apple Watch), this method uses `HKStatisticsQuery`
   * to return the correct deduplicated total.
   *
   * @param options - Query options with date range
   * @returns Object with totalSteps
   */
  async queryStepCount(options: QueryOptions): Promise<{ totalSteps: number }> {
    return bridge.call<{ totalSteps: number }>(
      'healthkit',
      'queryStepCount',
      options
    );
  },

  /**
   * Queries heart rate data.
   *
   * @param options - Query options with date range
   * @returns Array of heart rate samples
   */
  async queryHeartRate(options: QueryOptions): Promise<HealthSample[]> {
    const result = await bridge.call<{ samples: HealthSample[] }>(
      'healthkit',
      'queryHeartRate',
      options
    );
    return result.samples;
  },

  /**
   * Queries workout data.
   *
   * @param options - Query options with date range and optional activity type filter
   * @returns Array of workout data
   */
  async queryWorkouts(options: WorkoutQueryOptions): Promise<WorkoutData[]> {
    const result = await bridge.call<{ workouts: WorkoutData[] }>(
      'healthkit',
      'queryWorkouts',
      options
    );
    return result.workouts;
  },

  /**
   * Queries sleep analysis data.
   *
   * @param options - Query options with date range
   * @returns Array of sleep samples
   */
  async querySleep(options: QueryOptions): Promise<SleepSample[]> {
    const result = await bridge.call<{ samples: SleepSample[] }>(
      'healthkit',
      'querySleep',
      options
    );
    return result.samples;
  },

  /**
   * Saves a workout to HealthKit.
   *
   * @param request - Workout save request
   * @returns Result with success status
   *
   * @example
   * ```typescript
   * await ios.healthKit.saveWorkout({
   *   workoutType: 'running',
   *   startDate: '2024-01-15T07:00:00Z',
   *   endDate: '2024-01-15T07:30:00Z',
   *   calories: 350,
   *   distance: 5000
   * });
   * ```
   */
  async saveWorkout(
    request: SaveWorkoutRequest
  ): Promise<{ success: boolean; error?: string }> {
    return bridge.call('healthkit', 'saveWorkout', request);
  },
};
