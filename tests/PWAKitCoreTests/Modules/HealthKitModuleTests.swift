import Foundation
import Testing

@testable import PWAKitApp

// MARK: - HealthKitModuleTests

@Suite("HealthKitModule Tests")
struct HealthKitModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(HealthKitModule.moduleName == "healthkit")
    }

    @Test("Supports expected actions")
    func supportsExpectedActions() {
        #expect(HealthKitModule.supportedActions == [
            "isAvailable",
            "requestAuthorization",
            "querySteps",
            "queryHeartRate",
            "queryWorkouts",
            "querySleep",
            "saveWorkout",
        ])
        #expect(HealthKitModule.supports(action: "isAvailable"))
        #expect(HealthKitModule.supports(action: "requestAuthorization"))
        #expect(HealthKitModule.supports(action: "querySteps"))
        #expect(HealthKitModule.supports(action: "queryHeartRate"))
        #expect(HealthKitModule.supports(action: "queryWorkouts"))
        #expect(HealthKitModule.supports(action: "querySleep"))
        #expect(HealthKitModule.supports(action: "saveWorkout"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!HealthKitModule.supports(action: "unknown"))
        #expect(!HealthKitModule.supports(action: "getSteps"))
        #expect(!HealthKitModule.supports(action: "recordWorkout"))
        #expect(!HealthKitModule.supports(action: ""))
    }

    // MARK: - Is Available Action

    @Test("isAvailable returns availability response")
    @MainActor
    func isAvailableReturnsResponse() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "isAvailable",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["available"] != nil)
        // The value will be true or false depending on the device
        #expect(dict?["available"]?.boolValue != nil)
    }

    // MARK: - Request Authorization Action

    @Test("requestAuthorization accepts empty arrays")
    @MainActor
    func requestAuthorizationAcceptsEmptyArrays() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        // Test with empty read and write arrays - should not throw
        // Note: On devices without HealthKit, this may throw, so we catch the error
        do {
            let result = try await module.handle(
                action: "requestAuthorization",
                payload: AnyCodable(["read": AnyCodable([AnyCodable]()), "write": AnyCodable([AnyCodable]())]),
                context: context
            )
            // If it succeeds, verify the response format
            let dict = result?.dictionaryValue
            #expect(dict?["success"]?.boolValue == true)
        } catch {
            // HealthKit may not be available on this device, which is expected
            // The error should be a moduleError wrapping a HealthKitError
            #expect(error is BridgeError)
        }
    }

    @Test("requestAuthorization accepts nil payload")
    @MainActor
    func requestAuthorizationAcceptsNilPayload() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        // Should not throw for nil payload (empty read/write arrays)
        do {
            let result = try await module.handle(
                action: "requestAuthorization",
                payload: nil,
                context: context
            )
            let dict = result?.dictionaryValue
            #expect(dict?["success"]?.boolValue == true)
        } catch {
            // HealthKit may not be available
            #expect(error is BridgeError)
        }
    }

    // MARK: - Query Steps Action

    @Test("querySteps throws for missing startDate")
    @MainActor
    func queryStepsThrowsForMissingStartDate() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "querySteps",
                payload: AnyCodable(["endDate": AnyCodable("2024-01-15T00:00:00Z")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("startDate"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("querySteps throws for missing endDate")
    @MainActor
    func queryStepsThrowsForMissingEndDate() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "querySteps",
                payload: AnyCodable(["startDate": AnyCodable("2024-01-01T00:00:00Z")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("endDate"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("querySteps throws for invalid date format")
    @MainActor
    func queryStepsThrowsForInvalidDateFormat() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "querySteps",
                payload: AnyCodable([
                    "startDate": AnyCodable("not-a-date"),
                    "endDate": AnyCodable("2024-01-15T00:00:00Z"),
                ]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("startDate") || reason.contains("ISO8601"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Query Heart Rate Action

    @Test("queryHeartRate throws for missing dates")
    @MainActor
    func queryHeartRateThrowsForMissingDates() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "queryHeartRate",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("startDate"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Query Workouts Action

    @Test("queryWorkouts throws for missing dates")
    @MainActor
    func queryWorkoutsThrowsForMissingDates() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "queryWorkouts",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("startDate"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Query Sleep Action

    @Test("querySleep throws for missing dates")
    @MainActor
    func querySleepThrowsForMissingDates() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "querySleep",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("startDate"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Save Workout Action

    @Test("saveWorkout throws for missing workoutType")
    @MainActor
    func saveWorkoutThrowsForMissingWorkoutType() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "saveWorkout",
                payload: AnyCodable([
                    "startDate": AnyCodable("2024-01-15T07:00:00Z"),
                    "endDate": AnyCodable("2024-01-15T07:30:00Z"),
                ]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("workoutType"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("saveWorkout throws for invalid workoutType")
    @MainActor
    func saveWorkoutThrowsForInvalidWorkoutType() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "saveWorkout",
                payload: AnyCodable([
                    "workoutType": AnyCodable("invalid_type"),
                    "startDate": AnyCodable("2024-01-15T07:00:00Z"),
                    "endDate": AnyCodable("2024-01-15T07:30:00Z"),
                ]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("workoutType"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("saveWorkout throws for missing dates")
    @MainActor
    func saveWorkoutThrowsForMissingDates() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "saveWorkout",
                payload: AnyCodable([
                    "workoutType": AnyCodable("running"),
                ]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("startDate") || reason.contains("endDate"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "unknownAction",
                payload: nil,
                context: context
            )
        }
    }

    @Test("Throws specific error for unknown action")
    @MainActor
    func throwsSpecificErrorForUnknownAction() async {
        let module = HealthKitModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "badAction",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            #expect(error == BridgeError.unknownAction("badAction"))
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = HealthKitModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = HealthKitModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(HealthKitModule.moduleName == "healthkit")
        #expect(!HealthKitModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = HealthKitModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = HealthKitModule()

        try module.validateAction("isAvailable")
        try module.validateAction("requestAuthorization")
        try module.validateAction("querySteps")
        try module.validateAction("queryHeartRate")
        try module.validateAction("queryWorkouts")
        try module.validateAction("querySleep")
        try module.validateAction("saveWorkout")
        // Should not throw
    }

    // MARK: - Date Parsing Tests

    @Test("Accepts ISO8601 date with fractional seconds")
    @MainActor
    func acceptsISO8601WithFractionalSeconds() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        // Test with fractional seconds format
        do {
            _ = try await module.handle(
                action: "querySteps",
                payload: AnyCodable([
                    "startDate": AnyCodable("2024-01-01T00:00:00.000Z"),
                    "endDate": AnyCodable("2024-01-15T23:59:59.999Z"),
                ]),
                context: context
            )
            // If HealthKit is available and we get here, dates were parsed correctly
        } catch let error as BridgeError {
            // If it's a module error, dates were parsed correctly but HealthKit failed
            if case .moduleError = error {
                // Expected on devices without HealthKit
            } else if case let .invalidPayload(reason) = error {
                Issue.record("Date parsing failed: \(reason)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Accepts ISO8601 date without fractional seconds")
    @MainActor
    func acceptsISO8601WithoutFractionalSeconds() async throws {
        let module = HealthKitModule()
        let context = ModuleContext()

        // Test without fractional seconds format
        do {
            _ = try await module.handle(
                action: "querySteps",
                payload: AnyCodable([
                    "startDate": AnyCodable("2024-01-01T00:00:00Z"),
                    "endDate": AnyCodable("2024-01-15T23:59:59Z"),
                ]),
                context: context
            )
            // If HealthKit is available and we get here, dates were parsed correctly
        } catch let error as BridgeError {
            // If it's a module error, dates were parsed correctly but HealthKit failed
            if case .moduleError = error {
                // Expected on devices without HealthKit
            } else if case let .invalidPayload(reason) = error {
                Issue.record("Date parsing failed: \(reason)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

// MARK: - HealthKitModuleIntegrationTests

@Suite("HealthKitModule Integration Tests")
struct HealthKitModuleIntegrationTests {
    // Note: These tests require HealthKit to be available on the device.
    // They are structured to show how integration testing would be done
    // with actual HealthKit operations.

    @Test("Module can be initialized with default manager")
    func initWithDefaultManager() {
        let module = HealthKitModule()
        #expect(HealthKitModule.moduleName == "healthkit")
        _ = module
    }

    @Test("Module can be initialized with custom manager")
    func initWithCustomManager() {
        let manager = HealthKitManager()
        let module = HealthKitModule(healthKitManager: manager)
        #expect(HealthKitModule.moduleName == "healthkit")
        _ = module
    }
}
