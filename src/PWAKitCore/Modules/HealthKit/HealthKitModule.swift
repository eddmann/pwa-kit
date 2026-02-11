import Foundation
import HealthKit

// MARK: - HealthKitModule

/// A module that provides HealthKit functionality to JavaScript.
///
/// `HealthKitModule` exposes HealthKit operations to web applications, allowing
/// them to check availability, request authorization, query health data,
/// and save workouts.
///
/// ## Supported Actions
///
/// - `isAvailable`: Check if HealthKit is available on this device.
///   - Returns `{ available: true/false }`.
///
/// - `requestAuthorization`: Request permission to read/write health data.
///   - `read`: Array of quantity types to request read access for.
///   - `write`: Array of quantity types to request write access for.
///   - Returns `{ success: true }` on completion.
///
/// - `querySteps`: Query step count data for a date range.
///   - `startDate`: ISO8601 start date string.
///   - `endDate`: ISO8601 end date string.
///   - Returns `{ samples: [...] }`.
///
/// - `queryHeartRate`: Query heart rate data for a date range.
///   - `startDate`: ISO8601 start date string.
///   - `endDate`: ISO8601 end date string.
///   - Returns `{ samples: [...] }`.
///
/// - `queryWorkouts`: Query workout data for a date range.
///   - `startDate`: ISO8601 start date string.
///   - `endDate`: ISO8601 end date string.
///   - `type`: Optional workout type filter.
///   - Returns `{ workouts: [...] }`.
///
/// - `querySleep`: Query sleep analysis data for a date range.
///   - `startDate`: ISO8601 start date string.
///   - `endDate`: ISO8601 end date string.
///   - Returns `{ samples: [...] }`.
///
/// - `saveWorkout`: Save a workout to HealthKit.
///   - `workoutType`: The type of workout activity.
///   - `startDate`: ISO8601 start date string.
///   - `endDate`: ISO8601 end date string.
///   - `calories`: Optional energy burned in kilocalories.
///   - `distance`: Optional distance covered in meters.
///   - Returns `{ success: true/false, error?: string }`.
///
/// ## Example
///
/// JavaScript request to check availability:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "healthkit",
///   "action": "isAvailable",
///   "payload": null
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": {
///     "available": true
///   }
/// }
/// ```
///
/// JavaScript request to query steps:
/// ```json
/// {
///   "id": "def-456",
///   "module": "healthkit",
///   "action": "querySteps",
///   "payload": {
///     "startDate": "2024-01-01T00:00:00Z",
///     "endDate": "2024-01-15T23:59:59Z"
///   }
/// }
/// ```
@available(iOS 15.0, macOS 13.0, tvOS 15.0, watchOS 8.0, *)
public struct HealthKitModule: PWAModule {
    public static let moduleName = "healthkit"
    public static let supportedActions = [
        "isAvailable",
        "requestAuthorization",
        "querySteps",
        "queryHeartRate",
        "queryWorkouts",
        "querySleep",
        "saveWorkout",
    ]

    /// The HealthKit manager used for operations.
    private let healthKitManager: HealthKitManager

    /// ISO8601 date formatter for parsing date strings.
    /// Marked nonisolated(unsafe) because ISO8601DateFormatter is thread-safe for date parsing.
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Fallback ISO8601 date formatter without fractional seconds.
    /// Marked nonisolated(unsafe) because ISO8601DateFormatter is thread-safe for date parsing.
    private nonisolated(unsafe) static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Creates a new HealthKit module with a default manager.
    public init() {
        self.healthKitManager = HealthKitManager()
    }

    /// Creates a new HealthKit module with a custom manager.
    ///
    /// - Parameter healthKitManager: The HealthKit manager to use for operations.
    public init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "isAvailable":
            return handleIsAvailable()

        case "requestAuthorization":
            return try await handleRequestAuthorization(payload: payload)

        case "querySteps":
            return try await handleQuerySteps(payload: payload)

        case "queryHeartRate":
            return try await handleQueryHeartRate(payload: payload)

        case "queryWorkouts":
            return try await handleQueryWorkouts(payload: payload)

        case "querySleep":
            return try await handleQuerySleep(payload: payload)

        case "saveWorkout":
            return try await handleSaveWorkout(payload: payload)

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Is Available Action

    /// Handles the `isAvailable` action to check HealthKit availability.
    ///
    /// - Returns: A `HealthKitAvailabilityResponse` encoded as `AnyCodable`.
    private func handleIsAvailable() -> AnyCodable {
        let available = healthKitManager.isHealthKitAvailable()
        let response = HealthKitAvailabilityResponse(available: available)
        return encodeResponse(response)
    }

    // MARK: - Request Authorization Action

    /// Handles the `requestAuthorization` action to request HealthKit permissions.
    ///
    /// - Parameter payload: Dictionary containing `read` and `write` arrays.
    /// - Returns: Success response as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if payload is invalid,
    ///           `BridgeError.moduleError` if authorization fails.
    private func handleRequestAuthorization(payload: AnyCodable?) async throws -> AnyCodable {
        let readArray = payload?["read"]?.arrayValue ?? []
        let writeArray = payload?["write"]?.arrayValue ?? []
        let readWorkouts = payload?["readWorkouts"]?.boolValue ?? false
        let readSleep = payload?["readSleep"]?.boolValue ?? false
        let writeWorkouts = payload?["writeWorkouts"]?.boolValue ?? false

        let readTypes = readArray.compactMap(\.stringValue).compactMap { HealthQuantityType(rawValue: $0) }
        let writeTypes = writeArray.compactMap(\.stringValue).compactMap { HealthQuantityType(rawValue: $0) }

        do {
            try await healthKitManager.requestAuthorization(
                read: readTypes,
                write: writeTypes,
                readWorkouts: readWorkouts,
                readSleep: readSleep,
                writeWorkouts: writeWorkouts
            )
            return AnyCodable(["success": AnyCodable(true)])
        } catch let error as HealthKitError {
            throw BridgeError.moduleError(underlying: error)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Query Steps Action

    /// Handles the `querySteps` action to query step count data.
    ///
    /// - Parameter payload: Dictionary containing `startDate` and `endDate`.
    /// - Returns: A `HealthSamplesResponse` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if dates are missing or invalid.
    private func handleQuerySteps(payload: AnyCodable?) async throws -> AnyCodable {
        let (startDate, endDate) = try parseDateRange(from: payload)

        do {
            let samples = try await healthKitManager.querySteps(startDate: startDate, endDate: endDate)
            let response = HealthSamplesResponse(samples: samples)
            return encodeResponse(response)
        } catch let error as HealthKitError {
            throw BridgeError.moduleError(underlying: error)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Query Heart Rate Action

    /// Handles the `queryHeartRate` action to query heart rate data.
    ///
    /// - Parameter payload: Dictionary containing `startDate` and `endDate`.
    /// - Returns: A `HealthSamplesResponse` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if dates are missing or invalid.
    private func handleQueryHeartRate(payload: AnyCodable?) async throws -> AnyCodable {
        let (startDate, endDate) = try parseDateRange(from: payload)

        do {
            let samples = try await healthKitManager.queryHeartRate(startDate: startDate, endDate: endDate)
            let response = HealthSamplesResponse(samples: samples)
            return encodeResponse(response)
        } catch let error as HealthKitError {
            throw BridgeError.moduleError(underlying: error)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Query Workouts Action

    /// Handles the `queryWorkouts` action to query workout data.
    ///
    /// - Parameter payload: Dictionary containing `startDate`, `endDate`, and optional `type`.
    /// - Returns: A `WorkoutsResponse` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if dates are missing or invalid.
    private func handleQueryWorkouts(payload: AnyCodable?) async throws -> AnyCodable {
        let (startDate, endDate) = try parseDateRange(from: payload)

        var workoutType: WorkoutActivityType?
        if let typeString = payload?["type"]?.stringValue {
            workoutType = WorkoutActivityType(rawValue: typeString)
        }

        do {
            let workouts = try await healthKitManager.queryWorkouts(
                startDate: startDate,
                endDate: endDate,
                workoutType: workoutType
            )
            let response = WorkoutsResponse(workouts: workouts)
            return encodeResponse(response)
        } catch let error as HealthKitError {
            throw BridgeError.moduleError(underlying: error)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Query Sleep Action

    /// Handles the `querySleep` action to query sleep analysis data.
    ///
    /// - Parameter payload: Dictionary containing `startDate` and `endDate`.
    /// - Returns: A `SleepResponse` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if dates are missing or invalid.
    private func handleQuerySleep(payload: AnyCodable?) async throws -> AnyCodable {
        let (startDate, endDate) = try parseDateRange(from: payload)

        do {
            let samples = try await healthKitManager.querySleep(startDate: startDate, endDate: endDate)
            let response = SleepResponse(samples: samples)
            return encodeResponse(response)
        } catch let error as HealthKitError {
            throw BridgeError.moduleError(underlying: error)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Save Workout Action

    /// Handles the `saveWorkout` action to save a workout to HealthKit.
    ///
    /// - Parameter payload: Dictionary containing workout details.
    /// - Returns: A `SaveWorkoutResponse` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if required fields are missing.
    private func handleSaveWorkout(payload: AnyCodable?) async throws -> AnyCodable {
        guard let typeString = payload?["workoutType"]?.stringValue,
              let workoutType = WorkoutActivityType(rawValue: typeString) else
        {
            throw BridgeError.invalidPayload("Missing or invalid 'workoutType' field")
        }

        let (startDate, endDate) = try parseDateRange(from: payload)

        let calories = payload?["calories"]?.doubleValue
        let distance = payload?["distance"]?.doubleValue

        let request = SaveWorkoutRequest(
            workoutType: workoutType,
            startDate: startDate,
            endDate: endDate,
            calories: calories,
            distance: distance
        )

        do {
            try await healthKitManager.saveWorkout(request: request)
            let response = SaveWorkoutResponse()
            return encodeResponse(response)
        } catch let error as HealthKitError {
            let response = SaveWorkoutResponse(error: error.localizedDescription)
            return encodeResponse(response)
        } catch {
            let response = SaveWorkoutResponse(error: error.localizedDescription)
            return encodeResponse(response)
        }
    }

    // MARK: - Helpers

    /// Parses a date range from the payload.
    ///
    /// - Parameter payload: The payload containing `startDate` and `endDate` strings.
    /// - Returns: A tuple of (startDate, endDate) as `Date` objects.
    /// - Throws: `BridgeError.invalidPayload` if dates are missing or invalid.
    private func parseDateRange(from payload: AnyCodable?) throws -> (startDate: Date, endDate: Date) {
        guard let startDateString = payload?["startDate"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'startDate' field")
        }

        guard let endDateString = payload?["endDate"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'endDate' field")
        }

        guard let startDate = parseDate(startDateString) else {
            throw BridgeError.invalidPayload("Invalid 'startDate' format. Expected ISO8601 date string.")
        }

        guard let endDate = parseDate(endDateString) else {
            throw BridgeError.invalidPayload("Invalid 'endDate' format. Expected ISO8601 date string.")
        }

        return (startDate, endDate)
    }

    /// Parses an ISO8601 date string.
    ///
    /// - Parameter string: The date string to parse.
    /// - Returns: A `Date` object, or `nil` if parsing fails.
    private func parseDate(_ string: String) -> Date? {
        Self.iso8601Formatter.date(from: string) ?? Self.iso8601FormatterNoFraction.date(from: string)
    }

    /// Encodes a Codable response to AnyCodable.
    ///
    /// This converts a strongly-typed response to the dynamic AnyCodable
    /// format used by the bridge.
    private func encodeResponse(_ response: some Encodable) -> AnyCodable {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(response)
            let decoder = JSONDecoder()
            return try decoder.decode(AnyCodable.self, from: data)
        } catch {
            // Fallback to a simple error response if encoding fails
            return AnyCodable([
                "error": AnyCodable("Failed to encode response: \(error.localizedDescription)"),
            ])
        }
    }
}

// MARK: @unchecked Sendable

@available(iOS 15.0, macOS 13.0, tvOS 15.0, watchOS 8.0, *)
extension HealthKitModule: @unchecked Sendable {
    // HealthKitManager is an actor, so it's thread-safe.
    // The HealthKitModule itself is a struct with no mutable state,
    // making it safe to mark as @unchecked Sendable.
}
