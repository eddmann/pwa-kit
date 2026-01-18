import Foundation
import LocalAuthentication

/// A module that provides biometric authentication capabilities to JavaScript.
///
/// `BiometricsModule` exposes iOS biometric authentication (Face ID / Touch ID)
/// to web applications, allowing them to verify user identity using native
/// biometric hardware.
///
/// ## Supported Actions
///
/// - `isAvailable`: Check if biometric authentication is available.
///   - Returns: `{ available: true/false, biometryType: "faceId"/"touchId"/"none" }`
///
/// - `authenticate(reason)`: Prompt for biometric authentication.
///   - `reason`: Optional string explaining why authentication is needed
///   - Returns: `{ success: true }` on success, or `{ success: false, error: "..." }` on failure
///
/// ## Example
///
/// JavaScript request to check availability:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "biometrics",
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
///     "available": true,
///     "biometryType": "faceId"
///   }
/// }
/// ```
///
/// JavaScript request to authenticate:
/// ```json
/// {
///   "id": "def-456",
///   "module": "biometrics",
///   "action": "authenticate",
///   "payload": {
///     "reason": "Please authenticate to access your account"
///   }
/// }
/// ```
///
/// Response on success:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": { "success": true }
/// }
/// ```
///
/// Response on failure:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": {
///     "success": false,
///     "error": "User cancelled authentication",
///     "errorCode": "userCancel"
///   }
/// }
/// ```
///
/// ## Requirements
///
/// - Requires `NSFaceIDUsageDescription` in Info.plist for Face ID devices
public struct BiometricsModule: PWAModule {
    public static let moduleName = "biometrics"
    public static let supportedActions = ["isAvailable", "authenticate"]

    /// Creates a new biometrics module instance.
    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "isAvailable":
            return handleIsAvailable()

        case "authenticate":
            return await handleAuthenticate(payload: payload)

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Biometry Type

    /// The type of biometric authentication available.
    public enum BiometryType: String, Sendable, CaseIterable {
        /// Face ID authentication.
        case faceId
        /// Touch ID authentication.
        case touchId
        /// No biometric authentication available.
        case none

        /// Creates a BiometryType from LABiometryType.
        ///
        /// - Parameter laBiometryType: The LocalAuthentication biometry type.
        /// - Returns: The corresponding BiometryType.
        public static func from(_ laBiometryType: LABiometryType) -> BiometryType {
            switch laBiometryType {
            case .faceID:
                return .faceId
            case .touchID:
                return .touchId
            case .none:
                return .none
            case .opticID:
                return .none // Optic ID (Vision Pro) not supported in this mapping
            @unknown default:
                return .none
            }
        }
    }

    /// Error codes returned to JavaScript for authentication failures.
    public enum BiometricErrorCode: String, Sendable {
        /// Authentication failed.
        case authenticationFailed
        /// User cancelled authentication.
        case userCancel
        /// User selected fallback (password).
        case userFallback
        /// System cancelled authentication.
        case systemCancel
        /// Passcode not set on device.
        case passcodeNotSet
        /// Biometry not available.
        case biometryNotAvailable
        /// Biometry not enrolled.
        case biometryNotEnrolled
        /// Biometry locked out.
        case biometryLockout
        /// App cancelled authentication.
        case appCancel
        /// Invalid context.
        case invalidContext
        /// Unknown error.
        case unknown

        /// Creates a BiometricErrorCode from LAError.Code.
        ///
        /// - Parameter laErrorCode: The LocalAuthentication error code.
        /// - Returns: The corresponding BiometricErrorCode.
        public static func from(_ laErrorCode: LAError.Code) -> BiometricErrorCode {
            switch laErrorCode {
            case .authenticationFailed:
                return .authenticationFailed
            case .userCancel:
                return .userCancel
            case .userFallback:
                return .userFallback
            case .systemCancel:
                return .systemCancel
            case .passcodeNotSet:
                return .passcodeNotSet
            case .biometryNotAvailable,
                 .touchIDNotAvailable:
                return .biometryNotAvailable
            case .biometryNotEnrolled,
                 .touchIDNotEnrolled:
                return .biometryNotEnrolled
            case .biometryLockout,
                 .touchIDLockout:
                return .biometryLockout
            case .appCancel:
                return .appCancel
            case .invalidContext:
                return .invalidContext
            case .notInteractive:
                return .unknown
            case .biometryNotPaired,
                 .biometryDisconnected,
                 .invalidDimensions:
                return .unknown
            @unknown default:
                return .unknown
            }
        }
    }

    // MARK: - isAvailable Action

    /// Handles the `isAvailable` action to check if biometric authentication is available.
    ///
    /// - Returns: A dictionary with `available` boolean and `biometryType` string.
    private func handleIsAvailable() -> AnyCodable {
        let context = LAContext()
        var error: NSError?

        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        let biometryType = BiometryType.from(context.biometryType)

        return AnyCodable([
            "available": AnyCodable(canEvaluate),
            "biometryType": AnyCodable(biometryType.rawValue),
        ])
    }

    // MARK: - authenticate Action

    /// Handles the `authenticate` action to prompt for biometric authentication.
    ///
    /// - Parameter payload: Dictionary optionally containing `reason` string.
    /// - Returns: A dictionary with `success` boolean and optionally `error` and `errorCode`.
    private func handleAuthenticate(payload: AnyCodable?) async -> AnyCodable {
        let reason = payload?["reason"]?.stringValue ?? "Authenticate to continue"

        let context = LAContext()
        var error: NSError?

        // First check if biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let errorCode: BiometricErrorCode = if let laError = error as? LAError {
                BiometricErrorCode.from(laError.code)
            } else {
                .biometryNotAvailable
            }

            return AnyCodable([
                "success": AnyCodable(false),
                "error": AnyCodable(error?.localizedDescription ?? "Biometric authentication not available"),
                "errorCode": AnyCodable(errorCode.rawValue),
            ])
        }

        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                return AnyCodable([
                    "success": AnyCodable(true),
                ])
            } else {
                return AnyCodable([
                    "success": AnyCodable(false),
                    "error": AnyCodable("Authentication failed"),
                    "errorCode": AnyCodable(BiometricErrorCode.authenticationFailed.rawValue),
                ])
            }
        } catch let laError as LAError {
            let errorCode = BiometricErrorCode.from(laError.code)
            return AnyCodable([
                "success": AnyCodable(false),
                "error": AnyCodable(laError.localizedDescription),
                "errorCode": AnyCodable(errorCode.rawValue),
            ])
        } catch {
            return AnyCodable([
                "success": AnyCodable(false),
                "error": AnyCodable(error.localizedDescription),
                "errorCode": AnyCodable(BiometricErrorCode.unknown.rawValue),
            ])
        }
    }
}
