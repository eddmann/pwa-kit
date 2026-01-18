import CoreLocation
import Foundation
import Testing

@testable import PWAKitApp

@Suite("LocationPermissionModule Tests")
struct LocationPermissionModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(LocationPermissionModule.moduleName == "locationPermission")
    }

    @Test("Supports checkPermission and requestPermission actions")
    func supportsExpectedActions() {
        #expect(LocationPermissionModule.supportedActions == ["checkPermission", "requestPermission"])
        #expect(LocationPermissionModule.supports(action: "checkPermission"))
        #expect(LocationPermissionModule.supports(action: "requestPermission"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!LocationPermissionModule.supports(action: "unknown"))
        #expect(!LocationPermissionModule.supports(action: "getStatus"))
        #expect(!LocationPermissionModule.supports(action: ""))
    }

    // MARK: - PermissionStatus Enum

    @Test("PermissionStatus has all expected cases")
    func permissionStatusHasAllCases() {
        let allCases = LocationPermissionModule.PermissionStatus.allCases
        #expect(allCases.count == 4)
        #expect(allCases.map(\.rawValue).sorted() == ["denied", "granted", "notDetermined", "restricted"])
    }

    @Test("PermissionStatus raw values are correct")
    func permissionStatusRawValues() {
        #expect(LocationPermissionModule.PermissionStatus.granted.rawValue == "granted")
        #expect(LocationPermissionModule.PermissionStatus.denied.rawValue == "denied")
        #expect(LocationPermissionModule.PermissionStatus.notDetermined.rawValue == "notDetermined")
        #expect(LocationPermissionModule.PermissionStatus.restricted.rawValue == "restricted")
    }

    @Test("PermissionStatus converts from CLAuthorizationStatus correctly")
    func permissionStatusConvertsFromCLAuthorizationStatus() {
        #expect(LocationPermissionModule.PermissionStatus.from(.authorizedWhenInUse) == .granted)

        #expect(LocationPermissionModule.PermissionStatus.from(.authorizedAlways) == .granted)
        #expect(LocationPermissionModule.PermissionStatus.from(.denied) == .denied)
        #expect(LocationPermissionModule.PermissionStatus.from(.notDetermined) == .notDetermined)
        #expect(LocationPermissionModule.PermissionStatus.from(.restricted) == .restricted)
    }

    // MARK: - checkPermission Action

    @Test("checkPermission returns expected structure")
    @MainActor
    func checkPermissionReturnsExpectedStructure() async throws {
        let module = LocationPermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["status"]?.stringValue != nil)
    }

    @Test("checkPermission returns valid status")
    @MainActor
    func checkPermissionReturnsValidStatus() async throws {
        let module = LocationPermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        let status = result?.dictionaryValue?["status"]?.stringValue
        #expect(status != nil)

        // Status should be one of the valid values
        let validStatuses = ["granted", "denied", "notDetermined", "restricted"]
        #expect(validStatuses.contains(status ?? ""))
    }

    @Test("checkPermission ignores payload")
    @MainActor
    func checkPermissionIgnoresPayload() async throws {
        let module = LocationPermissionModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "checkPermission",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        let resultWithoutPayload = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        #expect(resultWithPayload == resultWithoutPayload)
    }

    // MARK: - requestPermission Action

    // Note: requestPermission tests that would trigger user interaction are skipped
    // when the current status is notDetermined, as they would block indefinitely
    // waiting for user input in the test environment.

    @Test("requestPermission returns expected structure when status already determined")
    @MainActor
    func requestPermissionReturnsExpectedStructureWhenDetermined() async throws {
        let module = LocationPermissionModule()
        let context = ModuleContext()

        // First check if we can safely test requestPermission
        let checkResult = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )
        let currentStatus = checkResult?.dictionaryValue?["status"]?.stringValue

        // Only test requestPermission if status is already determined
        // Otherwise it would block waiting for user interaction
        guard currentStatus != "notDetermined" else {
            // Status is notDetermined, skip this test as it would block
            return
        }

        let result = try await module.handle(
            action: "requestPermission",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["status"]?.stringValue != nil)
    }

    @Test("requestPermission returns same status as checkPermission when already determined")
    @MainActor
    func requestPermissionReturnsSameStatusWhenDetermined() async throws {
        let module = LocationPermissionModule()
        let context = ModuleContext()

        // First check if we can safely test requestPermission
        let checkResult = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )
        let currentStatus = checkResult?.dictionaryValue?["status"]?.stringValue

        // Only test requestPermission if status is already determined
        guard currentStatus != "notDetermined" else {
            // Status is notDetermined, skip this test as it would block
            return
        }

        let result = try await module.handle(
            action: "requestPermission",
            payload: nil,
            context: context
        )

        let status = result?.dictionaryValue?["status"]?.stringValue
        #expect(status == currentStatus)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = LocationPermissionModule()
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
        let module = LocationPermissionModule()
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
        let module = LocationPermissionModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(LocationPermissionModule.moduleName == "locationPermission")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = LocationPermissionModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(LocationPermissionModule.moduleName == "locationPermission")
        #expect(!LocationPermissionModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = LocationPermissionModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = LocationPermissionModule()

        try module.validateAction("checkPermission")
        try module.validateAction("requestPermission")
        // Should not throw
    }
}
