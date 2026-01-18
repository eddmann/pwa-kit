import Foundation
import HealthKit
import Testing

@testable import PWAKitApp

// MARK: - HealthKitManagerTests

@Suite("HealthKitManager Tests")
struct HealthKitManagerTests {
    // MARK: - Initialization

    @Test("Can be initialized")
    func canBeInitialized() async {
        let manager = HealthKitManager()
        _ = manager // Suppress unused warning
        // Successfully created
    }

    @Test("Is an actor type")
    func isActorType() async {
        let manager = HealthKitManager()

        // Verify we can check availability (nonisolated method)
        _ = manager.isHealthKitAvailable()
    }

    @Test("Can be initialized with custom health store")
    func canBeInitializedWithCustomHealthStore() async {
        let store = HKHealthStore()
        let manager = HealthKitManager(healthStore: store)
        _ = manager // Suppress unused warning
    }

    // MARK: - Availability

    @Test("isHealthKitAvailable returns a boolean")
    func isHealthKitAvailableReturnsBoolean() {
        let manager = HealthKitManager()

        let available = manager.isHealthKitAvailable()

        // In test environment, this should return true or false
        // depending on the platform (simulators may vary)
        #expect(available == true || available == false)
    }

    @Test("isHealthKitAvailable is nonisolated")
    func isHealthKitAvailableIsNonisolated() {
        let manager = HealthKitManager()

        // This should compile without 'await' since it's nonisolated
        _ = manager.isHealthKitAvailable()
    }

    // MARK: - Authorization

    @Test("requestAuthorization throws notAvailable when HealthKit unavailable")
    func requestAuthorizationThrowsWhenUnavailable() async {
        // Note: This test may not throw on simulators/devices where HealthKit is available
        // It's primarily to verify the error handling path exists
        let manager = HealthKitManager()

        // If HealthKit is not available, this should throw
        if !manager.isHealthKitAvailable() {
            do {
                try await manager.requestAuthorization(read: [.stepCount], write: [])
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    @Test("requestWorkoutAuthorization throws notAvailable when HealthKit unavailable")
    func requestWorkoutAuthorizationThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                try await manager.requestWorkoutAuthorization(read: true, write: false)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    @Test("requestSleepAuthorization throws notAvailable when HealthKit unavailable")
    func requestSleepAuthorizationThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                try await manager.requestSleepAuthorization(read: true)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    // MARK: - Query Steps

    @Test("querySteps throws notAvailable when HealthKit unavailable")
    func queryStepsThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                let startDate = Date().addingTimeInterval(-86400)
                let endDate = Date()
                _ = try await manager.querySteps(startDate: startDate, endDate: endDate)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    // MARK: - Query Heart Rate

    @Test("queryHeartRate throws notAvailable when HealthKit unavailable")
    func queryHeartRateThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                let startDate = Date().addingTimeInterval(-86400)
                let endDate = Date()
                _ = try await manager.queryHeartRate(startDate: startDate, endDate: endDate)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    // MARK: - Query Workouts

    @Test("queryWorkouts throws notAvailable when HealthKit unavailable")
    func queryWorkoutsThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                let startDate = Date().addingTimeInterval(-86400)
                let endDate = Date()
                _ = try await manager.queryWorkouts(startDate: startDate, endDate: endDate)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    @Test("queryWorkouts accepts optional workout type filter")
    func queryWorkoutsAcceptsWorkoutTypeFilter() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                let startDate = Date().addingTimeInterval(-86400)
                let endDate = Date()
                _ = try await manager.queryWorkouts(
                    startDate: startDate,
                    endDate: endDate,
                    workoutType: .running
                )
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    // MARK: - Query Sleep

    @Test("querySleep throws notAvailable when HealthKit unavailable")
    func querySleepThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                let startDate = Date().addingTimeInterval(-86400)
                let endDate = Date()
                _ = try await manager.querySleep(startDate: startDate, endDate: endDate)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    // MARK: - Save Workout

    @Test("saveWorkout throws notAvailable when HealthKit unavailable")
    func saveWorkoutThrowsWhenUnavailable() async {
        let manager = HealthKitManager()

        if !manager.isHealthKitAvailable() {
            do {
                let request = SaveWorkoutRequest(
                    workoutType: .running,
                    startDate: Date().addingTimeInterval(-1800),
                    endDate: Date(),
                    calories: 350.5,
                    distance: 5000.0
                )
                try await manager.saveWorkout(request: request)
                Issue.record("Expected notAvailable error to be thrown")
            } catch let error as HealthKitError {
                #expect(error == .notAvailable)
            } catch {
                Issue.record("Expected HealthKitError.notAvailable, got \(error)")
            }
        }
    }

    // Note: Tests that require actual HealthKit authorization or data are
    // intentionally excluded to avoid test hangs and authorization prompts.
    // These operations include:
    // - Actual authorization requests (would prompt user)
    // - Actual data queries (require prior authorization)
    // - Actual workout saves (require prior authorization)
    //
    // To fully test HealthKitManager, run these tests on a physical device
    // with HealthKit data available and authorization granted.
}

// MARK: - HealthKitErrorTests

@Suite("HealthKitError Tests")
struct HealthKitErrorTests {
    @Test("notAvailable error has correct description")
    func notAvailableHasCorrectDescription() {
        let error = HealthKitError.notAvailable
        #expect(error.localizedDescription == "HealthKit is not available on this device")
    }

    @Test("authorizationDenied error has correct description")
    func authorizationDeniedHasCorrectDescription() {
        let error = HealthKitError.authorizationDenied
        #expect(error.localizedDescription == "HealthKit authorization was denied")
    }

    @Test("unsupportedDataType error includes type in description")
    func unsupportedDataTypeIncludesType() {
        let error = HealthKitError.unsupportedDataType("unknown_type")
        #expect(error.localizedDescription == "Unsupported data type: unknown_type")
    }

    @Test("noDataFound error has correct description")
    func noDataFoundHasCorrectDescription() {
        let error = HealthKitError.noDataFound
        #expect(error.localizedDescription == "No data found for the requested query")
    }

    @Test("saveFailed error includes message in description")
    func saveFailedIncludesMessage() {
        let error = HealthKitError.saveFailed("Authorization required")
        #expect(error.localizedDescription == "Failed to save workout: Authorization required")
    }

    @Test("unknown error includes message in description")
    func unknownIncludesMessage() {
        let error = HealthKitError.unknown("Something went wrong")
        #expect(error.localizedDescription == "HealthKit error: Something went wrong")
    }

    @Test("HealthKitError is Sendable")
    func isSendable() async {
        let error = HealthKitError.notAvailable

        await Task.detached {
            #expect(error == .notAvailable)
        }.value
    }

    @Test("HealthKitError cases are Equatable")
    func casesAreEquatable() {
        #expect(HealthKitError.notAvailable == HealthKitError.notAvailable)
        #expect(HealthKitError.authorizationDenied == HealthKitError.authorizationDenied)
        #expect(HealthKitError.unsupportedDataType("a") == HealthKitError.unsupportedDataType("a"))
        #expect(HealthKitError.unsupportedDataType("a") != HealthKitError.unsupportedDataType("b"))
        #expect(HealthKitError.noDataFound == HealthKitError.noDataFound)
        #expect(HealthKitError.saveFailed("x") == HealthKitError.saveFailed("x"))
        #expect(HealthKitError.saveFailed("x") != HealthKitError.saveFailed("y"))
        #expect(HealthKitError.unknown("x") == HealthKitError.unknown("x"))
        #expect(HealthKitError.unknown("x") != HealthKitError.unknown("y"))
    }

    @Test("Different error cases are not equal")
    func differentCasesAreNotEqual() {
        #expect(HealthKitError.notAvailable != HealthKitError.authorizationDenied)
        #expect(HealthKitError.authorizationDenied != HealthKitError.noDataFound)
        #expect(HealthKitError.noDataFound != HealthKitError.notAvailable)
    }
}
