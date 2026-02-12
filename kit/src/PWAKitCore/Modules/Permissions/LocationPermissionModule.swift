@preconcurrency import CoreLocation
import Foundation

// MARK: - LocationPermissionModule

/// A module that provides location permission management to JavaScript.
///
/// `LocationPermissionModule` exposes iOS location permission APIs to web applications,
/// allowing them to check and request location access before using web-based location
/// features. The actual location tracking is handled by web APIs (Geolocation API).
///
/// ## Supported Actions
///
/// - `checkPermission`: Check the current location authorization status.
///   - Returns: `{ status: "granted"/"denied"/"notDetermined"/"restricted" }`
///
/// - `requestPermission`: Request location access permission from the user.
///   - Returns: `{ status: "granted"/"denied" }` after user responds to prompt
///
/// ## Permission States
///
/// - `granted`: User has authorized location access
/// - `denied`: User has denied location access
/// - `notDetermined`: User has not yet been asked for permission
/// - `restricted`: Location access is restricted (parental controls, MDM, etc.)
///
/// ## Example
///
/// JavaScript request to check permission:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "locationPermission",
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
///   "module": "locationPermission",
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
/// - Requires `NSLocationWhenInUseUsageDescription` in Info.plist
///
/// ## Note
///
/// This module only handles permission management. Actual location tracking
/// is performed using web APIs (navigator.geolocation).
public struct LocationPermissionModule: PWAModule {
    public static let moduleName = "locationPermission"
    public static let supportedActions = ["checkPermission", "requestPermission"]

    /// Creates a new location permission module instance.
    public init() {}

    public func handle(
        action: String,
        payload _: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "checkPermission":
            return await handleCheckPermission()

        case "requestPermission":
            return await handleRequestPermission()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Permission Status

    /// The location permission status values returned to JavaScript.
    public enum PermissionStatus: String, Sendable, CaseIterable {
        /// Location access has been granted.
        case granted
        /// Location access has been denied by the user.
        case denied
        /// User has not yet been prompted for permission.
        case notDetermined
        /// Location access is restricted (parental controls, MDM, etc.).
        case restricted

        /// Creates a PermissionStatus from CLAuthorizationStatus.
        ///
        /// - Parameter clStatus: The CoreLocation authorization status.
        /// - Returns: The corresponding PermissionStatus.
        public static func from(_ clStatus: CLAuthorizationStatus) -> PermissionStatus {
            switch clStatus {
            case .authorizedAlways,
                 .authorizedWhenInUse:
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

    /// Handles the `checkPermission` action to check the current location authorization status.
    ///
    /// - Returns: A dictionary with the current `status`.
    @MainActor
    private func handleCheckPermission() async -> AnyCodable {
        let delegate = LocationPermissionDelegate()
        let status = delegate.locationManager.authorizationStatus
        let permissionStatus = PermissionStatus.from(status)

        return AnyCodable([
            "state": AnyCodable(permissionStatus.rawValue),
        ])
    }

    // MARK: - requestPermission Action

    /// Handles the `requestPermission` action to request location access from the user.
    ///
    /// If permission has already been determined, this returns the current status
    /// without prompting the user again.
    ///
    /// - Returns: A dictionary with the resulting `status` after the user responds.
    @MainActor
    private func handleRequestPermission() async -> AnyCodable {
        let delegate = LocationPermissionDelegate()
        let currentStatus = delegate.locationManager.authorizationStatus

        // If already determined, return current status
        if currentStatus != .notDetermined {
            let permissionStatus = PermissionStatus.from(currentStatus)
            return AnyCodable([
                "state": AnyCodable(permissionStatus.rawValue),
            ])
        }

        // Request permission and wait for response
        let resultStatus = await delegate.requestWhenInUseAuthorization()
        let permissionStatus = PermissionStatus.from(resultStatus)

        return AnyCodable([
            "state": AnyCodable(permissionStatus.rawValue),
        ])
    }
}

// MARK: - LocationPermissionDelegate

/// A delegate class that handles CLLocationManager authorization changes.
///
/// This class is necessary because CLLocationManager requires a delegate object
/// to receive authorization status changes, and we need to bridge this callback-based
/// API to Swift's async/await concurrency model.
@MainActor
private final class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
    /// The location manager instance used for authorization requests.
    let locationManager: CLLocationManager

    /// Continuation used to bridge the delegate callback to async/await.
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }

    /// Requests when-in-use authorization and waits for the user's response.
    ///
    /// - Returns: The authorization status after the user responds.
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            self.authorizationContinuation = continuation
            self.locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            // Only resume if we have a pending continuation and status is determined
            if status != .notDetermined, let continuation = self.authorizationContinuation {
                self.authorizationContinuation = nil
                continuation.resume(returning: status)
            }
        }
    }
}
