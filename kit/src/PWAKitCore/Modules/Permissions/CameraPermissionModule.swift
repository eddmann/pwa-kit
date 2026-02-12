import AVFoundation
import Foundation

/// A module that provides camera permission management to JavaScript.
///
/// `CameraPermissionModule` exposes iOS camera permission APIs to web applications,
/// allowing them to check and request camera access before using web-based camera
/// features. The actual camera capture is handled by web APIs (getUserMedia).
///
/// ## Supported Actions
///
/// - `checkPermission`: Check the current camera authorization status.
///   - Returns: `{ status: "granted"/"denied"/"notDetermined"/"restricted" }`
///
/// - `requestPermission`: Request camera access permission from the user.
///   - Returns: `{ status: "granted"/"denied" }` after user responds to prompt
///
/// ## Permission States
///
/// - `granted`: User has authorized camera access
/// - `denied`: User has denied camera access
/// - `notDetermined`: User has not yet been asked for permission
/// - `restricted`: Camera access is restricted (parental controls, MDM, etc.)
///
/// ## Example
///
/// JavaScript request to check permission:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "cameraPermission",
///   "action": "checkPermission",
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
///     "status": "notDetermined"
///   }
/// }
/// ```
///
/// JavaScript request to request permission:
/// ```json
/// {
///   "id": "def-456",
///   "module": "cameraPermission",
///   "action": "requestPermission",
///   "payload": null
/// }
/// ```
///
/// Response after user grants:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": {
///     "status": "granted"
///   }
/// }
/// ```
///
/// ## Requirements
///
/// - Requires `NSCameraUsageDescription` in Info.plist
///
/// ## Note
///
/// This module only handles permission management. Actual camera capture
/// is performed using web APIs (navigator.mediaDevices.getUserMedia).
public struct CameraPermissionModule: PWAModule {
    public static let moduleName = "cameraPermission"
    public static let supportedActions = ["checkPermission", "requestPermission"]

    /// Creates a new camera permission module instance.
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

    // MARK: - Permission Status

    /// The camera permission status values returned to JavaScript.
    public enum PermissionStatus: String, Sendable, CaseIterable {
        /// Camera access has been granted.
        case granted
        /// Camera access has been denied by the user.
        case denied
        /// User has not yet been prompted for permission.
        case notDetermined
        /// Camera access is restricted (parental controls, MDM, etc.).
        case restricted

        /// Creates a PermissionStatus from AVAuthorizationStatus.
        ///
        /// - Parameter avStatus: The AVFoundation authorization status.
        /// - Returns: The corresponding PermissionStatus.
        public static func from(_ avStatus: AVAuthorizationStatus) -> PermissionStatus {
            switch avStatus {
            case .authorized:
                return .granted
            case .denied:
                return .denied
            case .notDetermined:
                return .notDetermined
            case .restricted:
                return .restricted
            @unknown default:
                return .denied
            }
        }
    }

    // MARK: - checkPermission Action

    /// Handles the `checkPermission` action to check the current camera authorization status.
    ///
    /// - Returns: A dictionary with the current `status`.
    private func handleCheckPermission() -> AnyCodable {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let permissionStatus = PermissionStatus.from(status)

        return AnyCodable([
            "state": AnyCodable(permissionStatus.rawValue),
        ])
    }

    // MARK: - requestPermission Action

    /// Handles the `requestPermission` action to request camera access from the user.
    ///
    /// If permission has already been determined, this returns the current status
    /// without prompting the user again.
    ///
    /// - Returns: A dictionary with the resulting `status` after the user responds.
    private func handleRequestPermission() async -> AnyCodable {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)

        // If already determined, return current status
        if currentStatus != .notDetermined {
            let permissionStatus = PermissionStatus.from(currentStatus)
            return AnyCodable([
                "state": AnyCodable(permissionStatus.rawValue),
            ])
        }

        // Request permission
        let granted = await AVCaptureDevice.requestAccess(for: .video)

        let status: PermissionStatus = granted ? .granted : .denied
        return AnyCodable([
            "state": AnyCodable(status.rawValue),
        ])
    }
}
