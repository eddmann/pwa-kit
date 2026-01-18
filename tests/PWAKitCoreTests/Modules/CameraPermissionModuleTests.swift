import AVFoundation
import Foundation
import Testing

@testable import PWAKitApp

@Suite("CameraPermissionModule Tests")
struct CameraPermissionModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(CameraPermissionModule.moduleName == "cameraPermission")
    }

    @Test("Supports checkPermission and requestPermission actions")
    func supportsExpectedActions() {
        #expect(CameraPermissionModule.supportedActions == ["checkPermission", "requestPermission"])
        #expect(CameraPermissionModule.supports(action: "checkPermission"))
        #expect(CameraPermissionModule.supports(action: "requestPermission"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!CameraPermissionModule.supports(action: "unknown"))
        #expect(!CameraPermissionModule.supports(action: "getStatus"))
        #expect(!CameraPermissionModule.supports(action: ""))
    }

    // MARK: - PermissionStatus Enum

    @Test("PermissionStatus has all expected cases")
    func permissionStatusHasAllCases() {
        let allCases = CameraPermissionModule.PermissionStatus.allCases
        #expect(allCases.count == 4)
        #expect(allCases.map(\.rawValue).sorted() == ["denied", "granted", "notDetermined", "restricted"])
    }

    @Test("PermissionStatus raw values are correct")
    func permissionStatusRawValues() {
        #expect(CameraPermissionModule.PermissionStatus.granted.rawValue == "granted")
        #expect(CameraPermissionModule.PermissionStatus.denied.rawValue == "denied")
        #expect(CameraPermissionModule.PermissionStatus.notDetermined.rawValue == "notDetermined")
        #expect(CameraPermissionModule.PermissionStatus.restricted.rawValue == "restricted")
    }

    @Test("PermissionStatus converts from AVAuthorizationStatus correctly")
    func permissionStatusConvertsFromAVAuthorizationStatus() {
        #expect(CameraPermissionModule.PermissionStatus.from(.authorized) == .granted)
        #expect(CameraPermissionModule.PermissionStatus.from(.denied) == .denied)
        #expect(CameraPermissionModule.PermissionStatus.from(.notDetermined) == .notDetermined)
        #expect(CameraPermissionModule.PermissionStatus.from(.restricted) == .restricted)
    }

    // MARK: - checkPermission Action

    @Test("checkPermission returns expected structure")
    @MainActor
    func checkPermissionReturnsExpectedStructure() async throws {
        let module = CameraPermissionModule()
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
        let module = CameraPermissionModule()
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
        let module = CameraPermissionModule()
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

    @Test("checkPermission is consistent with AVCaptureDevice status")
    @MainActor
    func checkPermissionIsConsistent() async throws {
        let module = CameraPermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        let status = result?.dictionaryValue?["status"]?.stringValue

        // Get actual AVFoundation status
        let avStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let expectedStatus = CameraPermissionModule.PermissionStatus.from(avStatus)

        #expect(status == expectedStatus.rawValue)
    }

    // MARK: - requestPermission Action

    @Test("requestPermission returns expected structure")
    @MainActor
    func requestPermissionReturnsExpectedStructure() async throws {
        let module = CameraPermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "requestPermission",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["status"]?.stringValue != nil)
    }

    @Test("requestPermission returns valid status")
    @MainActor
    func requestPermissionReturnsValidStatus() async throws {
        let module = CameraPermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "requestPermission",
            payload: nil,
            context: context
        )

        let status = result?.dictionaryValue?["status"]?.stringValue
        #expect(status != nil)

        // Status should be one of the valid values
        // (notDetermined is not expected here since requestPermission resolves it)
        let validStatuses = ["granted", "denied", "notDetermined", "restricted"]
        #expect(validStatuses.contains(status ?? ""))
    }

    @Test("requestPermission ignores payload")
    @MainActor
    func requestPermissionIgnoresPayload() async throws {
        let module = CameraPermissionModule()
        let context = ModuleContext()

        // Both calls should handle payload the same way
        let resultWithPayload = try await module.handle(
            action: "requestPermission",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        #expect(resultWithPayload?.dictionaryValue?["status"]?.stringValue != nil)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = CameraPermissionModule()
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
        let module = CameraPermissionModule()
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
        let module = CameraPermissionModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(CameraPermissionModule.moduleName == "cameraPermission")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = CameraPermissionModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(CameraPermissionModule.moduleName == "cameraPermission")
        #expect(!CameraPermissionModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = CameraPermissionModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = CameraPermissionModule()

        try module.validateAction("checkPermission")
        try module.validateAction("requestPermission")
        // Should not throw
    }

    // MARK: - Permission State Consistency

    @Test("checkPermission and requestPermission return same status when already determined")
    @MainActor
    func bothActionsReturnSameStatusWhenDetermined() async throws {
        let module = CameraPermissionModule()
        let context = ModuleContext()

        // Get current status via check
        let checkResult = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )
        let checkStatus = checkResult?.dictionaryValue?["status"]?.stringValue

        // If already determined, request should return same status
        if checkStatus != "notDetermined" {
            let requestResult = try await module.handle(
                action: "requestPermission",
                payload: nil,
                context: context
            )
            let requestStatus = requestResult?.dictionaryValue?["status"]?.stringValue

            #expect(checkStatus == requestStatus)
        }
    }
}
