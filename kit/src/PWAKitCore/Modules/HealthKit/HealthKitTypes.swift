import Foundation

// MARK: - HealthQuantityType

/// Supported HealthKit quantity types.
///
/// This enum defines the health data types that can be queried
/// and written through the HealthKit module.
///
/// ## Example
///
/// ```swift
/// let type = HealthQuantityType.stepCount
/// let encoded = try JSONEncoder().encode(type)
/// // "step_count"
/// ```
public enum HealthQuantityType: String, Codable, Sendable, Equatable, CaseIterable {
    /// Number of steps taken.
    case stepCount

    /// Heart rate in beats per minute.
    case heartRate

    /// Active energy burned in kilocalories.
    case activeEnergyBurned

    /// Basal energy burned (resting metabolic rate) in kilocalories.
    case basalEnergyBurned

    /// Distance walked or run in meters.
    case distanceWalkingRunning

    /// Distance cycled in meters.
    case distanceCycling

    /// Distance swum in meters.
    case distanceSwimming

    /// Flights of stairs climbed.
    case flightsClimbed

    /// Body mass in kilograms.
    case bodyMass

    /// Body mass index.
    case bodyMassIndex

    /// Height in meters.
    case height

    /// Blood oxygen saturation as a percentage (0-1).
    case oxygenSaturation

    /// Respiratory rate in breaths per minute.
    case respiratoryRate

    /// Resting heart rate in beats per minute.
    case restingHeartRate

    /// Heart rate variability in milliseconds.
    case heartRateVariability

    /// Walking heart rate average in beats per minute.
    case walkingHeartRateAverage

    /// Body temperature in degrees Celsius.
    case bodyTemperature

    /// Blood pressure systolic in mmHg.
    case bloodPressureSystolic

    /// Blood pressure diastolic in mmHg.
    case bloodPressureDiastolic

    /// Blood glucose in mg/dL.
    case bloodGlucose

    /// Dietary water in liters.
    case dietaryWater

    /// Dietary caffeine in milligrams.
    case dietaryCaffeine
}

// MARK: - WorkoutActivityType

/// Supported workout activity types.
///
/// This enum maps to HealthKit's `HKWorkoutActivityType` and is used
/// to communicate workout types to JavaScript.
///
/// ## Example
///
/// ```swift
/// let type = WorkoutActivityType.running
/// let encoded = try JSONEncoder().encode(type)
/// // "running"
/// ```
public enum WorkoutActivityType: String, Codable, Sendable, Equatable, CaseIterable {
    /// Running workout.
    case running

    /// Walking workout.
    case walking

    /// Cycling workout.
    case cycling

    /// Swimming workout.
    case swimming

    /// Elliptical workout.
    case elliptical

    /// Rowing workout.
    case rowing

    /// Stair climbing workout.
    case stairClimbing

    /// High intensity interval training.
    case hiit

    /// Yoga workout.
    case yoga

    /// Strength training workout.
    case strengthTraining

    /// Dance workout.
    case dance

    /// Core training workout.
    case coreTraining

    /// Pilates workout.
    case pilates

    /// Functional strength training.
    case functionalStrengthTraining

    /// Traditional strength training.
    case traditionalStrengthTraining

    /// Cross training workout.
    case crossTraining

    /// Mixed cardio workout.
    case mixedCardio

    /// Hiking workout.
    case hiking

    /// Other/unknown workout type.
    case other
}

// MARK: - SleepStage

/// Sleep analysis stages.
///
/// This enum represents the different stages of sleep that can be
/// recorded in HealthKit sleep analysis.
///
/// ## Example
///
/// ```swift
/// let stage = SleepStage.deepSleep
/// let encoded = try JSONEncoder().encode(stage)
/// // "deep_sleep"
/// ```
public enum SleepStage: String, Codable, Sendable, Equatable, CaseIterable {
    /// User is in bed but not necessarily asleep.
    case inBed

    /// Unspecified sleep state (asleep, but stage unknown).
    case asleepUnspecified

    /// Awake during sleep analysis period.
    case awake

    /// Core sleep (light sleep).
    case asleepCore

    /// Deep sleep stage.
    case asleepDeep

    /// REM sleep stage.
    case asleepREM
}

// MARK: - HealthSample

/// A health data sample representing a single measurement.
///
/// This type represents a quantity sample from HealthKit, such as
/// step count, heart rate, or other measurements.
///
/// ## Example
///
/// ```json
/// {
///   "value": 72.0,
///   "unit": "count/min",
///   "startDate": "2024-01-15T10:30:00Z",
///   "endDate": "2024-01-15T10:30:00Z",
///   "quantityType": "heart_rate"
/// }
/// ```
public struct HealthSample: Codable, Sendable, Equatable {
    /// The measured value.
    public let value: Double

    /// The unit of measurement (e.g., "count", "count/min", "kcal", "m").
    public let unit: String

    /// The start date of the sample.
    public let startDate: Date

    /// The end date of the sample.
    public let endDate: Date

    /// The type of quantity measured, if applicable.
    public let quantityType: HealthQuantityType?

    /// Creates a new health sample.
    ///
    /// - Parameters:
    ///   - value: The measured value.
    ///   - unit: The unit of measurement.
    ///   - startDate: The start date of the sample.
    ///   - endDate: The end date of the sample.
    ///   - quantityType: The type of quantity measured.
    public init(
        value: Double,
        unit: String,
        startDate: Date,
        endDate: Date,
        quantityType: HealthQuantityType? = nil
    ) {
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.quantityType = quantityType
    }
}

// MARK: - WorkoutData

/// Workout data representing a completed workout session.
///
/// This type contains all the relevant information about a workout,
/// including its type, duration, and energy expenditure.
///
/// ## Example
///
/// ```json
/// {
///   "type": "running",
///   "duration": 1800.0,
///   "calories": 350.5,
///   "distance": 5000.0,
///   "startDate": "2024-01-15T07:00:00Z",
///   "endDate": "2024-01-15T07:30:00Z"
/// }
/// ```
public struct WorkoutData: Codable, Sendable, Equatable {
    /// The type of workout activity.
    public let type: WorkoutActivityType

    /// The duration of the workout in seconds.
    public let duration: Double

    /// The total energy burned in kilocalories, if available.
    public let calories: Double?

    /// The total distance covered in meters, if available.
    public let distance: Double?

    /// The start date of the workout.
    public let startDate: Date

    /// The end date of the workout.
    public let endDate: Date

    /// Creates a new workout data instance.
    ///
    /// - Parameters:
    ///   - type: The type of workout activity.
    ///   - duration: The duration in seconds.
    ///   - calories: The energy burned in kilocalories.
    ///   - distance: The distance covered in meters.
    ///   - startDate: The start date of the workout.
    ///   - endDate: The end date of the workout.
    public init(
        type: WorkoutActivityType,
        duration: Double,
        calories: Double? = nil,
        distance: Double? = nil,
        startDate: Date,
        endDate: Date
    ) {
        self.type = type
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - SleepSample

/// A sleep sample representing a period of sleep analysis.
///
/// This type represents a sleep analysis sample from HealthKit,
/// indicating the sleep stage during a specific time period.
///
/// ## Example
///
/// ```json
/// {
///   "stage": "asleep_deep",
///   "startDate": "2024-01-15T01:30:00Z",
///   "endDate": "2024-01-15T02:45:00Z"
/// }
/// ```
public struct SleepSample: Codable, Sendable, Equatable {
    /// The sleep stage during this period.
    public let stage: SleepStage

    /// The start date of this sleep period.
    public let startDate: Date

    /// The end date of this sleep period.
    public let endDate: Date

    /// Creates a new sleep sample.
    ///
    /// - Parameters:
    ///   - stage: The sleep stage.
    ///   - startDate: The start date of the sleep period.
    ///   - endDate: The end date of the sleep period.
    public init(
        stage: SleepStage,
        startDate: Date,
        endDate: Date
    ) {
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - HealthQueryRequest

/// Request payload for querying health data.
///
/// ## Example
///
/// ```json
/// {
///   "quantityType": "step_count",
///   "startDate": "2024-01-01T00:00:00Z",
///   "endDate": "2024-01-15T23:59:59Z"
/// }
/// ```
public struct HealthQueryRequest: Codable, Sendable, Equatable {
    /// The type of quantity to query.
    public let quantityType: HealthQuantityType

    /// The start date for the query range.
    public let startDate: Date

    /// The end date for the query range.
    public let endDate: Date

    /// Creates a health query request.
    ///
    /// - Parameters:
    ///   - quantityType: The type of quantity to query.
    ///   - startDate: The start date for the query.
    ///   - endDate: The end date for the query.
    public init(
        quantityType: HealthQuantityType,
        startDate: Date,
        endDate: Date
    ) {
        self.quantityType = quantityType
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - WorkoutQueryRequest

/// Request payload for querying workouts.
///
/// ## Example
///
/// ```json
/// {
///   "startDate": "2024-01-01T00:00:00Z",
///   "endDate": "2024-01-15T23:59:59Z",
///   "workoutType": "running"
/// }
/// ```
public struct WorkoutQueryRequest: Codable, Sendable, Equatable {
    /// The start date for the query range.
    public let startDate: Date

    /// The end date for the query range.
    public let endDate: Date

    /// Optional workout type filter. If nil, all workout types are returned.
    public let workoutType: WorkoutActivityType?

    /// Creates a workout query request.
    ///
    /// - Parameters:
    ///   - startDate: The start date for the query.
    ///   - endDate: The end date for the query.
    ///   - workoutType: Optional filter for workout type.
    public init(
        startDate: Date,
        endDate: Date,
        workoutType: WorkoutActivityType? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.workoutType = workoutType
    }
}

// MARK: - SleepQueryRequest

/// Request payload for querying sleep data.
///
/// ## Example
///
/// ```json
/// {
///   "startDate": "2024-01-14T20:00:00Z",
///   "endDate": "2024-01-15T08:00:00Z"
/// }
/// ```
public struct SleepQueryRequest: Codable, Sendable, Equatable {
    /// The start date for the query range.
    public let startDate: Date

    /// The end date for the query range.
    public let endDate: Date

    /// Creates a sleep query request.
    ///
    /// - Parameters:
    ///   - startDate: The start date for the query.
    ///   - endDate: The end date for the query.
    public init(
        startDate: Date,
        endDate: Date
    ) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - SaveWorkoutRequest

/// Request payload for saving a workout.
///
/// ## Example
///
/// ```json
/// {
///   "workoutType": "running",
///   "startDate": "2024-01-15T07:00:00Z",
///   "endDate": "2024-01-15T07:30:00Z",
///   "calories": 350.5,
///   "distance": 5000.0
/// }
/// ```
public struct SaveWorkoutRequest: Codable, Sendable, Equatable {
    /// The type of workout activity.
    public let workoutType: WorkoutActivityType

    /// The start date of the workout.
    public let startDate: Date

    /// The end date of the workout.
    public let endDate: Date

    /// The energy burned in kilocalories, if available.
    public let calories: Double?

    /// The distance covered in meters, if available.
    public let distance: Double?

    /// Creates a save workout request.
    ///
    /// - Parameters:
    ///   - workoutType: The type of workout activity.
    ///   - startDate: The start date of the workout.
    ///   - endDate: The end date of the workout.
    ///   - calories: The energy burned in kilocalories.
    ///   - distance: The distance covered in meters.
    public init(
        workoutType: WorkoutActivityType,
        startDate: Date,
        endDate: Date,
        calories: Double? = nil,
        distance: Double? = nil
    ) {
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.calories = calories
        self.distance = distance
    }
}

// MARK: - AuthorizationRequest

/// Request payload for HealthKit authorization.
///
/// ## Example
///
/// ```json
/// {
///   "read": ["step_count", "heart_rate"],
///   "write": ["step_count"]
/// }
/// ```
public struct AuthorizationRequest: Codable, Sendable, Equatable {
    /// The quantity types to request read access for.
    public let read: [HealthQuantityType]

    /// The quantity types to request write access for.
    public let write: [HealthQuantityType]

    /// Creates an authorization request.
    ///
    /// - Parameters:
    ///   - read: The quantity types to request read access for.
    ///   - write: The quantity types to request write access for.
    public init(
        read: [HealthQuantityType],
        write: [HealthQuantityType] = []
    ) {
        self.read = read
        self.write = write
    }
}

// MARK: - StepCountResponse

/// Response containing a deduplicated total step count.
///
/// ## Example
///
/// ```json
/// {
///   "totalSteps": 6509
/// }
/// ```
public struct StepCountResponse: Codable, Sendable, Equatable {
    /// The total deduplicated step count.
    public let totalSteps: Double

    /// Creates a step count response.
    ///
    /// - Parameter totalSteps: The total step count.
    public init(totalSteps: Double) {
        self.totalSteps = totalSteps
    }
}

// MARK: - HealthSamplesResponse

/// Response containing health samples.
///
/// ## Example
///
/// ```json
/// {
///   "samples": [
///     {
///       "value": 72.0,
///       "unit": "count/min",
///       "startDate": "2024-01-15T10:30:00Z",
///       "endDate": "2024-01-15T10:30:00Z"
///     }
///   ]
/// }
/// ```
public struct HealthSamplesResponse: Codable, Sendable, Equatable {
    /// The list of health samples.
    public let samples: [HealthSample]

    /// Creates a health samples response.
    ///
    /// - Parameter samples: The list of health samples.
    public init(samples: [HealthSample]) {
        self.samples = samples
    }

    /// An empty response with no samples.
    public static let empty = HealthSamplesResponse(samples: [])
}

// MARK: - WorkoutsResponse

/// Response containing workouts.
///
/// ## Example
///
/// ```json
/// {
///   "workouts": [
///     {
///       "type": "running",
///       "duration": 1800.0,
///       "calories": 350.5,
///       "startDate": "2024-01-15T07:00:00Z",
///       "endDate": "2024-01-15T07:30:00Z"
///     }
///   ]
/// }
/// ```
public struct WorkoutsResponse: Codable, Sendable, Equatable {
    /// The list of workouts.
    public let workouts: [WorkoutData]

    /// Creates a workouts response.
    ///
    /// - Parameter workouts: The list of workouts.
    public init(workouts: [WorkoutData]) {
        self.workouts = workouts
    }

    /// An empty response with no workouts.
    public static let empty = WorkoutsResponse(workouts: [])
}

// MARK: - SleepResponse

/// Response containing sleep samples.
///
/// ## Example
///
/// ```json
/// {
///   "samples": [
///     {
///       "stage": "asleep_deep",
///       "startDate": "2024-01-15T01:30:00Z",
///       "endDate": "2024-01-15T02:45:00Z"
///     }
///   ]
/// }
/// ```
public struct SleepResponse: Codable, Sendable, Equatable {
    /// The list of sleep samples.
    public let samples: [SleepSample]

    /// Creates a sleep response.
    ///
    /// - Parameter samples: The list of sleep samples.
    public init(samples: [SleepSample]) {
        self.samples = samples
    }

    /// An empty response with no samples.
    public static let empty = SleepResponse(samples: [])
}

// MARK: - HealthKitAvailabilityResponse

/// Response for HealthKit availability check.
///
/// ## Example
///
/// ```json
/// {
///   "available": true
/// }
/// ```
public struct HealthKitAvailabilityResponse: Codable, Sendable, Equatable {
    /// Whether HealthKit is available on this device.
    public let available: Bool

    /// Creates a HealthKit availability response.
    ///
    /// - Parameter available: Whether HealthKit is available.
    public init(available: Bool) {
        self.available = available
    }
}

// MARK: - SaveWorkoutResponse

/// Response for save workout operation.
///
/// ## Example
///
/// Successful save:
/// ```json
/// {
///   "success": true
/// }
/// ```
///
/// Failed save:
/// ```json
/// {
///   "success": false,
///   "error": "HealthKit authorization denied"
/// }
/// ```
public struct SaveWorkoutResponse: Codable, Sendable, Equatable {
    /// Whether the save operation was successful.
    public let success: Bool

    /// Error message if the save failed.
    public let error: String?

    /// Creates a successful save response.
    public init() {
        self.success = true
        self.error = nil
    }

    /// Creates a failed save response.
    ///
    /// - Parameter error: A description of why the save failed.
    public init(error: String) {
        self.success = false
        self.error = error
    }

    /// Creates a save response with all fields.
    ///
    /// - Parameters:
    ///   - success: Whether the operation was successful.
    ///   - error: Error message, if any.
    public init(success: Bool, error: String?) {
        self.success = success
        self.error = error
    }
}
