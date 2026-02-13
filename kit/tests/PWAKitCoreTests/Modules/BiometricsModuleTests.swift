import Foundation
import LocalAuthentication
@testable import PWAKitApp
import Testing

@Suite("BiometricsModule Tests")
struct BiometricsModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(BiometricsModule.moduleName == "biometrics")
    }

    @Test("Supports isAvailable and authenticate actions")
    func supportsExpectedActions() {
        #expect(BiometricsModule.supportedActions == ["isAvailable", "authenticate"])
        #expect(BiometricsModule.supports(action: "isAvailable"))
        #expect(BiometricsModule.supports(action: "authenticate"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!BiometricsModule.supports(action: "unknown"))
        #expect(!BiometricsModule.supports(action: "verify"))
        #expect(!BiometricsModule.supports(action: ""))
    }

    // MARK: - BiometryType Enum

    @Test("BiometryType has all expected cases")
    func biometryTypeHasAllCases() {
        let allCases = BiometricsModule.BiometryType.allCases
        #expect(allCases.count == 3)
        #expect(allCases.map(\.rawValue).sorted() == ["faceId", "none", "touchId"])
    }

    @Test("BiometryType raw values are correct")
    func biometryTypeRawValues() {
        #expect(BiometricsModule.BiometryType.faceId.rawValue == "faceId")
        #expect(BiometricsModule.BiometryType.touchId.rawValue == "touchId")
        #expect(BiometricsModule.BiometryType.none.rawValue == "none")
    }

    @Test("BiometryType converts from LABiometryType correctly")
    func biometryTypeConvertsFromLABiometryType() {
        #expect(BiometricsModule.BiometryType.from(.faceID) == .faceId)
        #expect(BiometricsModule.BiometryType.from(.touchID) == .touchId)
        #expect(BiometricsModule.BiometryType.from(.none) == .none)
        if #available(iOS 17.0, *) {
            #expect(BiometricsModule.BiometryType.from(.opticID) == .none)
        }
    }

    // MARK: - BiometricErrorCode Enum

    @Test("BiometricErrorCode has expected values")
    func biometricErrorCodeValues() {
        #expect(BiometricsModule.BiometricErrorCode.authenticationFailed.rawValue == "authenticationFailed")
        #expect(BiometricsModule.BiometricErrorCode.userCancel.rawValue == "userCancel")
        #expect(BiometricsModule.BiometricErrorCode.userFallback.rawValue == "userFallback")
        #expect(BiometricsModule.BiometricErrorCode.systemCancel.rawValue == "systemCancel")
        #expect(BiometricsModule.BiometricErrorCode.passcodeNotSet.rawValue == "passcodeNotSet")
        #expect(BiometricsModule.BiometricErrorCode.biometryNotAvailable.rawValue == "biometryNotAvailable")
        #expect(BiometricsModule.BiometricErrorCode.biometryNotEnrolled.rawValue == "biometryNotEnrolled")
        #expect(BiometricsModule.BiometricErrorCode.biometryLockout.rawValue == "biometryLockout")
        #expect(BiometricsModule.BiometricErrorCode.appCancel.rawValue == "appCancel")
        #expect(BiometricsModule.BiometricErrorCode.invalidContext.rawValue == "invalidContext")
        #expect(BiometricsModule.BiometricErrorCode.unknown.rawValue == "unknown")
    }

    @Test("BiometricErrorCode converts from LAError.Code correctly")
    func biometricErrorCodeConvertsFromLAError() {
        #expect(BiometricsModule.BiometricErrorCode.from(.authenticationFailed) == .authenticationFailed)
        #expect(BiometricsModule.BiometricErrorCode.from(.userCancel) == .userCancel)
        #expect(BiometricsModule.BiometricErrorCode.from(.userFallback) == .userFallback)
        #expect(BiometricsModule.BiometricErrorCode.from(.systemCancel) == .systemCancel)
        #expect(BiometricsModule.BiometricErrorCode.from(.passcodeNotSet) == .passcodeNotSet)
        #expect(BiometricsModule.BiometricErrorCode.from(.biometryNotAvailable) == .biometryNotAvailable)
        #expect(BiometricsModule.BiometricErrorCode.from(.touchIDNotAvailable) == .biometryNotAvailable)
        #expect(BiometricsModule.BiometricErrorCode.from(.biometryNotEnrolled) == .biometryNotEnrolled)
        #expect(BiometricsModule.BiometricErrorCode.from(.touchIDNotEnrolled) == .biometryNotEnrolled)
        #expect(BiometricsModule.BiometricErrorCode.from(.biometryLockout) == .biometryLockout)
        #expect(BiometricsModule.BiometricErrorCode.from(.touchIDLockout) == .biometryLockout)
        #expect(BiometricsModule.BiometricErrorCode.from(.appCancel) == .appCancel)
        #expect(BiometricsModule.BiometricErrorCode.from(.invalidContext) == .invalidContext)
        #expect(BiometricsModule.BiometricErrorCode.from(.notInteractive) == .unknown)
        // Note: watchNotAvailable, biometryNotPaired, biometryDisconnected, invalidDimensions
        // are macOS-only error codes and not available on iOS
    }

    // MARK: - isAvailable Action

    @Test("isAvailable returns expected structure")
    @MainActor
    func isAvailableReturnsExpectedStructure() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "isAvailable",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["available"]?.boolValue != nil)
        #expect(dict?["biometryType"]?.stringValue != nil)
    }

    @Test("isAvailable returns valid biometry type")
    @MainActor
    func isAvailableReturnsValidBiometryType() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "isAvailable",
            payload: nil,
            context: context
        )

        let biometryType = result?.dictionaryValue?["biometryType"]?.stringValue
        #expect(biometryType != nil)

        // biometryType should be one of the valid values
        let validTypes = ["faceId", "touchId", "none"]
        #expect(validTypes.contains(biometryType ?? ""))
    }

    @Test("isAvailable ignores payload")
    @MainActor
    func isAvailableIgnoresPayload() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "isAvailable",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        let resultWithoutPayload = try await module.handle(
            action: "isAvailable",
            payload: nil,
            context: context
        )

        #expect(resultWithPayload == resultWithoutPayload)
    }

    // MARK: - authenticate Action Error Handling

    @Test("authenticate returns failure when biometrics not available")
    @MainActor
    func authenticateReturnsFailureWhenNotAvailable() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        // First check if biometrics are available
        let availabilityResult = try await module.handle(
            action: "isAvailable",
            payload: nil,
            context: context
        )

        let available = availabilityResult?.dictionaryValue?["available"]?.boolValue ?? false

        // On simulator or devices without biometrics, authenticate should return failure
        if !available {
            let result = try await module.handle(
                action: "authenticate",
                payload: AnyCodable(["reason": AnyCodable("Test authentication")]),
                context: context
            )

            let dict = result?.dictionaryValue
            #expect(dict != nil)
            #expect(dict?["success"]?.boolValue == false)
            #expect(dict?["error"]?.stringValue != nil)
            #expect(dict?["errorCode"]?.stringValue != nil)
        }
    }

    @Test("authenticate uses default reason when not provided")
    @MainActor
    func authenticateUsesDefaultReason() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        // This should not throw even without a reason
        let result = try await module.handle(
            action: "authenticate",
            payload: nil,
            context: context
        )

        // Result should be valid (either success or failure structure)
        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["success"]?.boolValue != nil)
    }

    @Test("authenticate accepts custom reason")
    @MainActor
    func authenticateAcceptsCustomReason() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        // This should not throw with a custom reason
        let result = try await module.handle(
            action: "authenticate",
            payload: AnyCodable(["reason": AnyCodable("Custom reason for testing")]),
            context: context
        )

        // Result should be valid (either success or failure structure)
        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["success"]?.boolValue != nil)
    }

    @Test("authenticate result has valid error code on failure")
    @MainActor
    func authenticateHasValidErrorCodeOnFailure() async throws {
        let module = BiometricsModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "authenticate",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)

        // If authentication failed, check error code is valid
        if dict?["success"]?.boolValue == false {
            let errorCode = dict?["errorCode"]?.stringValue
            #expect(errorCode != nil)

            // Error code should be one of the valid values
            let validErrorCodes = [
                "authenticationFailed", "userCancel", "userFallback", "systemCancel",
                "passcodeNotSet", "biometryNotAvailable", "biometryNotEnrolled",
                "biometryLockout", "appCancel", "invalidContext", "unknown",
            ]
            #expect(validErrorCodes.contains(errorCode ?? ""))
        }
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = BiometricsModule()
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
        let module = BiometricsModule()
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
        let module = BiometricsModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(BiometricsModule.moduleName == "biometrics")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = BiometricsModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(BiometricsModule.moduleName == "biometrics")
        #expect(!BiometricsModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = BiometricsModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = BiometricsModule()

        try module.validateAction("isAvailable")
        try module.validateAction("authenticate")
        // Should not throw
    }
}
