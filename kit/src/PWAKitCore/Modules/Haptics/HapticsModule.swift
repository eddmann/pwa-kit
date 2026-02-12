import Foundation
import UIKit

// MARK: - HapticsModule

/// A module that provides haptic feedback capabilities to JavaScript.
///
/// `HapticsModule` exposes iOS haptic feedback generators to web applications,
/// allowing them to trigger tactile feedback in response to user interactions.
///
/// ## Supported Actions
///
/// - `impact(style)`: Triggers impact feedback using `UIImpactFeedbackGenerator`.
///   - Styles: `light`, `medium`, `heavy`, `soft`, `rigid`
///
/// - `notification(type)`: Triggers notification feedback using `UINotificationFeedbackGenerator`.
///   - Types: `success`, `warning`, `error`
///
/// - `selection()`: Triggers selection feedback using `UISelectionFeedbackGenerator`.
///
/// ## Example
///
/// JavaScript request for impact feedback:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "haptics",
///   "action": "impact",
///   "payload": { "style": "medium" }
/// }
/// ```
///
/// JavaScript request for notification feedback:
/// ```json
/// {
///   "id": "def-456",
///   "module": "haptics",
///   "action": "notification",
///   "payload": { "type": "success" }
/// }
/// ```
///
/// JavaScript request for selection feedback:
/// ```json
/// {
///   "id": "ghi-789",
///   "module": "haptics",
///   "action": "selection"
/// }
/// ```
///
/// Response on success:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "triggered": true }
/// }
/// ```
public struct HapticsModule: PWAModule {
    public static let moduleName = "haptics"
    public static let supportedActions = ["impact", "notification", "selection"]

    /// Creates a new haptics module instance.
    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "impact":
            return try await handleImpact(payload: payload)

        case "notification":
            return try await handleNotification(payload: payload)

        case "selection":
            return await handleSelection()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Impact Feedback

    /// Impact feedback styles matching UIImpactFeedbackGenerator.FeedbackStyle.
    public enum ImpactStyle: String, CaseIterable, Sendable {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    /// Handles the `impact` action to trigger impact feedback.
    ///
    /// - Parameter payload: Dictionary containing a `style` key with one of:
    ///   `light`, `medium`, `heavy`, `soft`, `rigid`.
    /// - Returns: A dictionary with `triggered: true` on success.
    /// - Throws: `BridgeError.invalidPayload` if the style is invalid.
    private func handleImpact(payload: AnyCodable?) async throws -> AnyCodable {
        let styleString = payload?["style"]?.stringValue ?? "medium"

        guard let style = ImpactStyle(rawValue: styleString) else {
            let validStyles = ImpactStyle.allCases.map(\.rawValue).joined(separator: ", ")
            throw BridgeError.invalidPayload(
                "Invalid impact style: '\(styleString)'. Valid styles: \(validStyles)"
            )
        }

        await triggerImpact(style: style)

        return AnyCodable([
            "triggered": AnyCodable(true),
        ])
    }

    /// Triggers the impact feedback generator on the main actor.
    @MainActor
    private func triggerImpact(style: ImpactStyle) {
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
        case .light:
            .light
        case .medium:
            .medium
        case .heavy:
            .heavy
        case .soft:
            .soft
        case .rigid:
            .rigid
        }

        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Notification feedback types matching UINotificationFeedbackGenerator.FeedbackType.
    public enum NotificationType: String, CaseIterable, Sendable {
        case success
        case warning
        case error
    }

    /// Handles the `notification` action to trigger notification feedback.
    ///
    /// - Parameter payload: Dictionary containing a `type` key with one of:
    ///   `success`, `warning`, `error`.
    /// - Returns: A dictionary with `triggered: true` on success.
    /// - Throws: `BridgeError.invalidPayload` if the type is invalid.
    private func handleNotification(payload: AnyCodable?) async throws -> AnyCodable {
        let typeString = payload?["type"]?.stringValue ?? "success"

        guard let notificationType = NotificationType(rawValue: typeString) else {
            let validTypes = NotificationType.allCases.map(\.rawValue).joined(separator: ", ")
            throw BridgeError.invalidPayload(
                "Invalid notification type: '\(typeString)'. Valid types: \(validTypes)"
            )
        }

        await triggerNotification(type: notificationType)

        return AnyCodable([
            "triggered": AnyCodable(true),
        ])
    }

    /// Triggers the notification feedback generator on the main actor.
    @MainActor
    private func triggerNotification(type: NotificationType) {
        let feedbackType: UINotificationFeedbackGenerator.FeedbackType = switch type {
        case .success:
            .success
        case .warning:
            .warning
        case .error:
            .error
        }

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(feedbackType)
    }

    // MARK: - Selection Feedback

    /// Handles the `selection` action to trigger selection feedback.
    ///
    /// Selection feedback is typically used for UI selection changes,
    /// like scrolling through a picker or toggling a switch.
    ///
    /// - Returns: A dictionary with `triggered: true` on success.
    private func handleSelection() async -> AnyCodable {
        await triggerSelection()

        return AnyCodable([
            "triggered": AnyCodable(true),
        ])
    }

    /// Triggers the selection feedback generator on the main actor.
    @MainActor
    private func triggerSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
