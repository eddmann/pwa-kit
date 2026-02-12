import Foundation
import UIKit

// MARK: - ClipboardModule

/// A module that provides native clipboard access to JavaScript.
///
/// `ClipboardModule` exposes iOS system clipboard (UIPasteboard) functionality
/// to web applications, allowing them to read from and write to the clipboard.
///
/// ## Supported Actions
///
/// - `write`: Copy text to the system clipboard.
///   - `text`: Required string to copy to clipboard.
///
/// - `read`: Read text from the system clipboard.
///   - Returns `{ text: "..." }` or `{ text: null }` if empty.
///
/// ## iOS 16+ Note
///
/// Starting with iOS 16, reading from the clipboard may trigger a system
/// permission prompt asking the user to allow paste access. This is a
/// privacy feature and cannot be bypassed.
///
/// ## Example
///
/// JavaScript request to write to clipboard:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "clipboard",
///   "action": "write",
///   "payload": {
///     "text": "Hello, World!"
///   }
/// }
/// ```
///
/// Response on success:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "copied": true }
/// }
/// ```
///
/// JavaScript request to read from clipboard:
/// ```json
/// {
///   "id": "def-456",
///   "module": "clipboard",
///   "action": "read",
///   "payload": null
/// }
/// ```
///
/// Response with text:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": { "text": "Hello, World!" }
/// }
/// ```
public struct ClipboardModule: PWAModule {
    public static let moduleName = "clipboard"
    public static let supportedActions = ["write", "read"]

    /// Creates a new clipboard module instance.
    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "write":
            return try await handleWrite(payload: payload)

        case "read":
            return await handleRead()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Write Action

    /// Handles the `write` action to copy text to the clipboard.
    ///
    /// - Parameter payload: Dictionary containing the text to copy.
    ///   - `text`: Required string to copy to clipboard.
    /// - Returns: A dictionary with `copied: true` on success.
    /// - Throws: `BridgeError.invalidPayload` if text is missing.
    private func handleWrite(payload: AnyCodable?) async throws -> AnyCodable {
        guard let text = payload?["text"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'text' field")
        }

        await MainActor.run {
            UIPasteboard.general.string = text
        }
        return AnyCodable([
            "copied": AnyCodable(true),
        ])
    }

    // MARK: - Read Action

    /// Handles the `read` action to read text from the clipboard.
    ///
    /// - Returns: A dictionary with `text` containing clipboard content or `null`.
    ///
    /// - Note: On iOS 16+, this may trigger a system paste permission prompt.
    private func handleRead() async -> AnyCodable {
        let text = await MainActor.run {
            UIPasteboard.general.string
        }
        if let text {
            return AnyCodable([
                "text": AnyCodable(text),
            ])
        } else {
            return AnyCodable([
                "text": AnyCodable.null,
            ])
        }
    }
}
