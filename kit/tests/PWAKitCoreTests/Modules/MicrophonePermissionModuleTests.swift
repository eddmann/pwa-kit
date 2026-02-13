import AVFoundation
import Foundation
@testable import PWAKitApp
import Testing

@Suite("MicrophonePermissionModule Tests")
struct MicrophonePermissionModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(MicrophonePermissionModule.moduleName == "microphonePermission")
    }

    @Test("Supports checkPermission and requestPermission actions")
    func supportsExpectedActions() {
        #expect(MicrophonePermissionModule.supportedActions == ["checkPermission", "requestPermission"])
        #expect(MicrophonePermissionModule.supports(action: "checkPermission"))
        #expect(MicrophonePermissionModule.supports(action: "requestPermission"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!MicrophonePermissionModule.supports(action: "unknown"))
        #expect(!MicrophonePermissionModule.supports(action: "getStatus"))
        #expect(!MicrophonePermissionModule.supports(action: ""))
    }

    // MARK: - checkPermission Action

    @Test("checkPermission returns expected structure")
    @MainActor
    func checkPermissionReturnsExpectedStructure() async throws {
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["state"]?.stringValue != nil)
    }

    @Test("checkPermission returns valid state")
    @MainActor
    func checkPermissionReturnsValidState() async throws {
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        let state = result?.dictionaryValue?["state"]?.stringValue
        #expect(state != nil)

        let validStates = ["granted", "denied", "notDetermined", "restricted"]
        #expect(validStates.contains(state ?? ""))
    }

    @Test("checkPermission ignores payload")
    @MainActor
    func checkPermissionIgnoresPayload() async throws {
        let module = MicrophonePermissionModule()
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
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )

        let state = result?.dictionaryValue?["state"]?.stringValue

        // Get actual AVFoundation status for audio
        let avStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let expectedState = CameraPermissionModule.PermissionStatus.from(avStatus)

        #expect(state == expectedState.rawValue)
    }

    // MARK: - requestPermission Action

    @Test("requestPermission returns expected structure")
    @MainActor
    func requestPermissionReturnsExpectedStructure() async throws {
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "requestPermission",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["state"]?.stringValue != nil)
    }

    @Test("requestPermission returns valid state")
    @MainActor
    func requestPermissionReturnsValidState() async throws {
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "requestPermission",
            payload: nil,
            context: context
        )

        let state = result?.dictionaryValue?["state"]?.stringValue
        #expect(state != nil)

        let validStates = ["granted", "denied", "notDetermined", "restricted"]
        #expect(validStates.contains(state ?? ""))
    }

    @Test("requestPermission ignores payload")
    @MainActor
    func requestPermissionIgnoresPayload() async throws {
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "requestPermission",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        #expect(resultWithPayload?.dictionaryValue?["state"]?.stringValue != nil)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = MicrophonePermissionModule()
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
        let module = MicrophonePermissionModule()
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
        let module = MicrophonePermissionModule()

        await Task.detached {
            #expect(MicrophonePermissionModule.moduleName == "microphonePermission")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = MicrophonePermissionModule()

        let _: any PWAModule = module

        #expect(MicrophonePermissionModule.moduleName == "microphonePermission")
        #expect(!MicrophonePermissionModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = MicrophonePermissionModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = MicrophonePermissionModule()

        try module.validateAction("checkPermission")
        try module.validateAction("requestPermission")
    }

    // MARK: - Permission State Consistency

    @Test("checkPermission and requestPermission return same state when already determined")
    @MainActor
    func bothActionsReturnSameStateWhenDetermined() async throws {
        let module = MicrophonePermissionModule()
        let context = ModuleContext()

        let checkResult = try await module.handle(
            action: "checkPermission",
            payload: nil,
            context: context
        )
        let checkState = checkResult?.dictionaryValue?["state"]?.stringValue

        if checkState != "notDetermined" {
            let requestResult = try await module.handle(
                action: "requestPermission",
                payload: nil,
                context: context
            )
            let requestState = requestResult?.dictionaryValue?["state"]?.stringValue

            #expect(checkState == requestState)
        }
    }
}
