import Foundation
import HealthKit

// MARK: - HealthKitError

/// Error types specific to HealthKit operations.
///
/// These errors provide more specific information about HealthKit failures
/// than the generic `BridgeError` type.
public enum HealthKitError: Error, Sendable, Equatable, LocalizedError {
    /// HealthKit is not available on this device.
    case notAvailable

    /// HealthKit authorization was denied.
    case authorizationDenied

    /// HealthKit authorization has not been requested yet.
    case authorizationNotDetermined

    /// The requested data type is not supported.
    case unsupportedDataType(String)

    /// No data was found for the requested query.
    case noDataFound

    /// Failed to save data to HealthKit.
    case saveFailed(String)

    /// An unknown HealthKit error occurred.
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "HealthKit is not available on this device"
        case .authorizationDenied:
            "HealthKit authorization was denied"
        case .authorizationNotDetermined:
            "HealthKit authorization not requested. Call requestAuthorization first."
        case let .unsupportedDataType(type):
            "Unsupported data type: \(type)"
        case .noDataFound:
            "No data found for the requested query"
        case let .saveFailed(message):
            "Failed to save workout: \(message)"
        case let .unknown(message):
            "HealthKit error: \(message)"
        }
    }
}

// MARK: - HealthKitManager

/// Manages HealthKit data operations.
///
/// `HealthKitManager` provides an async/await interface for:
/// - Checking HealthKit availability
/// - Requesting authorization for health data types
/// - Querying steps, heart rate, workouts, and sleep data
/// - Saving workout data
///
/// ## Usage
///
/// ```swift
/// let manager = HealthKitManager()
///
/// // Check availability
/// let isAvailable = manager.isHealthKitAvailable()
///
/// // Request authorization
/// try await manager.requestAuthorization(read: [.stepCount, .heartRate], write: [])
///
/// // Query steps
/// let steps = try await manager.querySteps(startDate: startDate, endDate: endDate)
///
/// // Save workout
/// try await manager.saveWorkout(request: saveRequest)
/// ```
///
/// ## Thread Safety
///
/// `HealthKitManager` is implemented as an actor to ensure thread-safe
/// access to the HealthKit store.
@available(iOS 15.0, macOS 13.0, tvOS 15.0, watchOS 8.0, *)
public actor HealthKitManager {
    /// The HealthKit store for data operations.
    private let healthStore: HKHealthStore

    /// Creates a new HealthKit manager.
    ///
    /// - Note: This initializer creates a new HKHealthStore instance.
    ///   If HealthKit is not available, operations will fail with `HealthKitError.notAvailable`.
    public init() {
        self.healthStore = HKHealthStore()
    }

    /// Creates a new HealthKit manager with a custom health store.
    ///
    /// This initializer is primarily intended for testing purposes.
    ///
    /// - Parameter healthStore: The HKHealthStore instance to use.
    public init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Availability

    /// Checks if HealthKit is available on this device.
    ///
    /// HealthKit is not available on:
    /// - iPad (prior to iPadOS 17)
    /// - Mac without Apple Silicon
    /// - Simulators for some device types
    ///
    /// - Returns: `true` if HealthKit is available on this device.
    public nonisolated func isHealthKitAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Requests authorization to read and/or write specific health data types.
    ///
    /// The user will be prompted to grant or deny access for each requested type.
    /// Note that HealthKit does not reveal whether the user granted or denied
    /// access for specific types due to privacy restrictions.
    ///
    /// - Parameters:
    ///   - readTypes: The quantity types to request read access for.
    ///   - writeTypes: The quantity types to request write access for.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available,
    ///           `HealthKitError.authorizationDenied` if the user denied access.
    public func requestAuthorization(
        read readTypes: [HealthQuantityType],
        write writeTypes: [HealthQuantityType]
    ) async throws {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        var readSet: Set<HKObjectType> = []
        var writeSet: Set<HKSampleType> = []

        // Convert quantity types to HKObjectType for reading
        for type in readTypes {
            if let hkType = hkQuantityType(for: type) {
                readSet.insert(hkType)
            }
        }

        // Add sleep analysis type if querying sleep
        readSet.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)

        // Add workout type for reading workouts
        readSet.insert(HKObjectType.workoutType())

        // Convert quantity types to HKSampleType for writing
        for type in writeTypes {
            if let hkType = hkQuantityType(for: type) {
                writeSet.insert(hkType)
            }
        }

        // Always request workout write permission if any write permissions are requested
        if !writeTypes.isEmpty {
            writeSet.insert(HKObjectType.workoutType())
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeSet, read: readSet)
        } catch {
            throw HealthKitError.unknown(error.localizedDescription)
        }
    }

    /// Requests authorization for workouts specifically.
    ///
    /// - Parameters:
    ///   - read: Whether to request read permission for workouts.
    ///   - write: Whether to request write permission for workouts.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available.
    public func requestWorkoutAuthorization(read: Bool, write: Bool) async throws {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        var readSet: Set<HKObjectType> = []
        var writeSet: Set<HKSampleType> = []

        if read {
            readSet.insert(HKObjectType.workoutType())
        }

        if write {
            writeSet.insert(HKObjectType.workoutType())
        }

        do {
            try await healthStore.requestAuthorization(toShare: writeSet, read: readSet)
        } catch {
            throw HealthKitError.unknown(error.localizedDescription)
        }
    }

    /// Requests authorization for sleep analysis.
    ///
    /// - Parameter read: Whether to request read permission for sleep analysis.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available.
    public func requestSleepAuthorization(read: Bool) async throws {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        var readSet: Set<HKObjectType> = []

        if read {
            readSet.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readSet)
        } catch {
            throw HealthKitError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Query Steps

    /// Queries step count data for a date range.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    /// - Returns: An array of health samples representing step counts.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available,
    ///           `HealthKitError.unsupportedDataType` if step count is not supported.
    public func querySteps(startDate: Date, endDate: Date) async throws -> [HealthSample] {
        try await queryQuantitySamples(
            type: .stepCount,
            startDate: startDate,
            endDate: endDate,
            unit: HKUnit.count()
        )
    }

    // MARK: - Query Heart Rate

    /// Queries heart rate data for a date range.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    /// - Returns: An array of health samples representing heart rate measurements.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available.
    public func queryHeartRate(startDate: Date, endDate: Date) async throws -> [HealthSample] {
        try await queryQuantitySamples(
            type: .heartRate,
            startDate: startDate,
            endDate: endDate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute())
        )
    }

    // MARK: - Query Workouts

    /// Queries workout data for a date range.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    ///   - workoutType: Optional filter for a specific workout type.
    /// - Returns: An array of workout data.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available.
    public func queryWorkouts(
        startDate: Date,
        endDate: Date,
        workoutType: WorkoutActivityType? = nil
    ) async throws -> [WorkoutData] {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.unknown(error.localizedDescription))
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                var results: [WorkoutData] = []

                for workout in workouts {
                    let activityType = self.workoutActivityType(from: workout.workoutActivityType)

                    // Filter by workout type if specified
                    if let filterType = workoutType, activityType != filterType {
                        continue
                    }

                    let calories = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
                    let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter())

                    let workoutData = WorkoutData(
                        type: activityType,
                        duration: workout.duration,
                        calories: calories,
                        distance: distance,
                        startDate: workout.startDate,
                        endDate: workout.endDate
                    )

                    results.append(workoutData)
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Query Sleep

    /// Queries sleep analysis data for a date range.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    /// - Returns: An array of sleep samples.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available.
    public func querySleep(startDate: Date, endDate: Date) async throws -> [SleepSample] {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.unsupportedDataType("sleepAnalysis")
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.unknown(error.localizedDescription))
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                var results: [SleepSample] = []

                for sample in categorySamples {
                    let stage = self.sleepStage(from: sample.value)

                    let sleepSample = SleepSample(
                        stage: stage,
                        startDate: sample.startDate,
                        endDate: sample.endDate
                    )

                    results.append(sleepSample)
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Save Workout

    /// Saves a workout to HealthKit.
    ///
    /// - Parameter request: The workout save request containing workout details.
    /// - Throws: `HealthKitError.notAvailable` if HealthKit is not available,
    ///           `HealthKitError.saveFailed` if the save operation fails.
    public func saveWorkout(request: SaveWorkoutRequest) async throws {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        let workoutActivityType = hkWorkoutActivityType(for: request.workoutType)

        var energyBurned: HKQuantity?
        if let calories = request.calories {
            energyBurned = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
        }

        var distance: HKQuantity?
        if let distanceValue = request.distance {
            distance = HKQuantity(unit: HKUnit.meter(), doubleValue: distanceValue)
        }

        let workout = HKWorkout(
            activityType: workoutActivityType,
            start: request.startDate,
            end: request.endDate,
            duration: request.endDate.timeIntervalSince(request.startDate),
            totalEnergyBurned: energyBurned,
            totalDistance: distance,
            metadata: nil
        )

        do {
            try await healthStore.save(workout)
        } catch {
            throw HealthKitError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    /// Queries quantity samples for a specific type.
    private func queryQuantitySamples(
        type: HealthQuantityType,
        startDate: Date,
        endDate: Date,
        unit: HKUnit
    ) async throws -> [HealthSample] {
        guard isHealthKitAvailable() else {
            throw HealthKitError.notAvailable
        }

        guard let quantityType = hkQuantityType(for: type) else {
            throw HealthKitError.unsupportedDataType(type.rawValue)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.unknown(error.localizedDescription))
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = quantitySamples.map { sample in
                    HealthSample(
                        value: sample.quantity.doubleValue(for: unit),
                        unit: unit.unitString,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        quantityType: type
                    )
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    /// Mapping from HealthQuantityType to HKQuantityTypeIdentifier.
    private static let quantityTypeMapping: [HealthQuantityType: HKQuantityTypeIdentifier] = [
        .stepCount: .stepCount,
        .heartRate: .heartRate,
        .activeEnergyBurned: .activeEnergyBurned,
        .basalEnergyBurned: .basalEnergyBurned,
        .distanceWalkingRunning: .distanceWalkingRunning,
        .distanceCycling: .distanceCycling,
        .distanceSwimming: .distanceSwimming,
        .flightsClimbed: .flightsClimbed,
        .bodyMass: .bodyMass,
        .bodyMassIndex: .bodyMassIndex,
        .height: .height,
        .oxygenSaturation: .oxygenSaturation,
        .respiratoryRate: .respiratoryRate,
        .restingHeartRate: .restingHeartRate,
        .heartRateVariability: .heartRateVariabilitySDNN,
        .walkingHeartRateAverage: .walkingHeartRateAverage,
        .bodyTemperature: .bodyTemperature,
        .bloodPressureSystolic: .bloodPressureSystolic,
        .bloodPressureDiastolic: .bloodPressureDiastolic,
        .bloodGlucose: .bloodGlucose,
        .dietaryWater: .dietaryWater,
        .dietaryCaffeine: .dietaryCaffeine,
    ]

    /// Converts a HealthQuantityType to HKQuantityType.
    private nonisolated func hkQuantityType(for type: HealthQuantityType) -> HKQuantityType? {
        guard let identifier = Self.quantityTypeMapping[type] else {
            return nil
        }
        return HKQuantityType.quantityType(forIdentifier: identifier)
    }

    /// Converts a WorkoutActivityType to HKWorkoutActivityType.
    private nonisolated func hkWorkoutActivityType(for type: WorkoutActivityType) -> HKWorkoutActivityType {
        switch type {
        case .running:
            .running
        case .walking:
            .walking
        case .cycling:
            .cycling
        case .swimming:
            .swimming
        case .elliptical:
            .elliptical
        case .rowing:
            .rowing
        case .stairClimbing:
            .stairClimbing
        case .hiit:
            .highIntensityIntervalTraining
        case .yoga:
            .yoga
        case .strengthTraining:
            .traditionalStrengthTraining
        case .dance:
            .dance
        case .coreTraining:
            .coreTraining
        case .pilates:
            .pilates
        case .functionalStrengthTraining:
            .functionalStrengthTraining
        case .traditionalStrengthTraining:
            .traditionalStrengthTraining
        case .crossTraining:
            .crossTraining
        case .mixedCardio:
            .mixedCardio
        case .hiking:
            .hiking
        case .other:
            .other
        }
    }

    /// Converts an HKWorkoutActivityType to WorkoutActivityType.
    private nonisolated func workoutActivityType(from hkType: HKWorkoutActivityType) -> WorkoutActivityType {
        switch hkType {
        case .running:
            .running
        case .walking:
            .walking
        case .cycling:
            .cycling
        case .swimming:
            .swimming
        case .elliptical:
            .elliptical
        case .rowing:
            .rowing
        case .stairClimbing:
            .stairClimbing
        case .highIntensityIntervalTraining:
            .hiit
        case .yoga:
            .yoga
        case .traditionalStrengthTraining:
            .traditionalStrengthTraining
        case .dance:
            .dance
        case .coreTraining:
            .coreTraining
        case .pilates:
            .pilates
        case .functionalStrengthTraining:
            .functionalStrengthTraining
        case .crossTraining:
            .crossTraining
        case .mixedCardio:
            .mixedCardio
        case .hiking:
            .hiking
        default:
            .other
        }
    }

    /// Converts an HKCategoryValueSleepAnalysis value to SleepStage.
    private nonisolated func sleepStage(from value: Int) -> SleepStage {
        guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: value) else {
            return .asleepUnspecified
        }

        switch sleepValue {
        case .inBed:
            return .inBed
        case .awake:
            return .awake
        case .asleepCore:
            return .asleepCore
        case .asleepDeep:
            return .asleepDeep
        case .asleepREM:
            return .asleepREM
        case .asleepUnspecified:
            return .asleepUnspecified
        @unknown default:
            return .asleepUnspecified
        }
    }
}
