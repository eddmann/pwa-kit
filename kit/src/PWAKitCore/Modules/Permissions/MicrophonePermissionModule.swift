import AVFoundation
import Foundation

/// A module that provides microphone permission management to JavaScript.
///
/// `MicrophonePermissionModule` exposes iOS microphone permission APIs to web applications,
/// allowing them to check and request microphone access before using web-based audio
/// features. The actual audio capture is handled by web APIs (getUserMedia).
///
/// ## Supported Actions
///
/// - `checkPermission`: Check the current microphone authorization status.
///   - Returns: `{ state: "granted"/"denied"/"notDetermined"/"restricted" }`
///
/// - `requestPermission`: Request microphone access permission from the user.
///   - Returns: `{ state: "granted"/"denied" }` after user responds to prompt
///
/// ## Requirements
///
/// - Requires `NSMicrophoneUsageDescription` in Info.plist
///
/// ## Note
///
/// This module only handles permission management. Actual audio capture
/// is performed using web APIs (navigator.mediaDevices.getUserMedia).
public struct MicrophonePermissionModule: PWAModule {
    public static let moduleName = "microphonePermission"
    public static let supportedActions = ["checkPermission", "requestPermission"]

    /// Creates a new microphone permission module instance.
    public init() {}

    public func handle(
        action: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "checkPermission":
            return handleCheckPermission()

        case "requestPermission":
            return await handleRequestPermission()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - checkPermission Action

    /// Handles the `checkPermission` action to check the current microphone authorization status.
    ///
    /// - Returns: A dictionary with the current `state`.
    private func handleCheckPermission() -> AnyCodable {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let state = CameraPermissionModule.PermissionStatus.from(status)

        return AnyCodable([
            "state": AnyCodable(state.rawValue),
        ])
    }

    // MARK: - requestPermission Action

    /// Handles the `requestPermission` action to request microphone access from the user.
    ///
    /// If permission has already been determined, this returns the current status
    /// without prompting the user again.
    ///
    /// - Returns: A dictionary with the resulting `state` after the user responds.
    private func handleRequestPermission() async -> AnyCodable {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        // If already determined, return current status
        if currentStatus != .notDetermined {
            let state = CameraPermissionModule.PermissionStatus.from(currentStatus)
            return AnyCodable([
                "state": AnyCodable(state.rawValue),
            ])
        }

        // Request permission
        let granted = await AVCaptureDevice.requestAccess(for: .audio)

        let state: CameraPermissionModule.PermissionStatus = granted ? .granted : .denied
        return AnyCodable([
            "state": AnyCodable(state.rawValue),
        ])
    }
}
