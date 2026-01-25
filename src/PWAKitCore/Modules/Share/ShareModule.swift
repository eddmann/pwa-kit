import Foundation
import UIKit

// MARK: - ShareModule

/// A module that provides native share sheet capabilities to JavaScript.
///
/// `ShareModule` exposes iOS sharing functionality to web applications,
/// allowing them to present the native share sheet with various content types.
///
/// ## Supported Actions
///
/// - `share(title?, text?, url?, files?)`: Present UIActivityViewController with the specified content.
///   - `title`: Optional subject line (used in email, etc.)
///   - `text`: Optional text to share
///   - `url`: Optional URL to share
///   - `files`: Optional array of file objects with `name`, `type`, and `data` (base64)
///
/// - `canShare(data?)`: Check if sharing is possible for the given data types.
///   - Returns `{ available: true }` if sharing is available
///
/// ## Example
///
/// JavaScript request to share a URL:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "share",
///   "action": "share",
///   "payload": {
///     "title": "Check this out!",
///     "text": "I found something interesting",
///     "url": "https://example.com"
///   }
/// }
/// ```
///
/// JavaScript request to share files:
/// ```json
/// {
///   "id": "def-456",
///   "module": "share",
///   "action": "share",
///   "payload": {
///     "files": [
///       {
///         "name": "document.pdf",
///         "type": "application/pdf",
///         "data": "base64encodeddata..."
///       }
///     ]
///   }
/// }
/// ```
///
/// Response on success:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "shared": true }
/// }
/// ```
///
/// Response when user cancelled:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "shared": false, "cancelled": true }
/// }
/// ```
public struct ShareModule: PWAModule {
    public static let moduleName = "share"
    public static let supportedActions = ["share", "canShare"]

    /// Creates a new share module instance.
    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "share":
            return try await handleShare(payload: payload, context: context)

        case "canShare":
            return handleCanShare(payload: payload)

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Share Action

    /// Represents a file to be shared.
    public struct ShareFile: Sendable {
        /// The filename including extension.
        public let name: String
        /// The MIME type of the file.
        public let type: String
        /// The file data.
        public let data: Data

        /// Creates a ShareFile from a payload dictionary.
        ///
        /// - Parameter payload: Dictionary containing `name`, `type`, and `data` (base64).
        /// - Returns: A ShareFile if parsing succeeds, nil otherwise.
        public static func from(payload: AnyCodable?) -> ShareFile? {
            guard let name = payload?["name"]?.stringValue,
                  let type = payload?["type"]?.stringValue,
                  let dataString = payload?["data"]?.stringValue,
                  let data = Data(base64Encoded: dataString) else
            {
                return nil
            }
            return ShareFile(name: name, type: type, data: data)
        }
    }

    /// Handles the `share` action to present the share sheet.
    ///
    /// - Parameters:
    ///   - payload: Dictionary containing share content (title, text, url, files).
    ///   - context: The module context containing view controller reference.
    /// - Returns: A dictionary with `shared: true/false` and optionally `cancelled: true`.
    /// - Throws: `BridgeError.invalidPayload` if no content to share or view controller unavailable.
    private func handleShare(payload: AnyCodable?, context: ModuleContext) async throws -> AnyCodable {
        let title = payload?["title"]?.stringValue
        let text = payload?["text"]?.stringValue
        let urlString = payload?["url"]?.stringValue
        let filesPayload = payload?["files"]?.arrayValue

        // Build items to share
        var items: [Any] = []

        // Add text content
        if let text {
            items.append(text)
        }

        // Add URL
        if let urlString, let url = URL(string: urlString) {
            items.append(url)
        }

        // Process files
        var temporaryFileURLs: [URL] = []
        if let filesPayload {
            for filePayload in filesPayload {
                if let file = ShareFile.from(payload: filePayload) {
                    // Create temporary file
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathComponent(file.name)

                    do {
                        // Create directory if needed
                        try FileManager.default.createDirectory(
                            at: tempURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        // Write file data
                        try file.data.write(to: tempURL)
                        items.append(tempURL)
                        temporaryFileURLs.append(tempURL)
                    } catch {
                        // Clean up any files we already created
                        cleanupTemporaryFiles(temporaryFileURLs)
                        throw BridgeError.moduleError(underlying: error)
                    }
                }
            }
        }

        // Validate we have something to share
        guard !items.isEmpty else {
            throw BridgeError.invalidPayload("No content to share. Provide at least one of: text, url, or files.")
        }

        // Present share sheet on main actor
        let result = try await presentShareSheet(
            items: items,
            title: title,
            temporaryFileURLs: temporaryFileURLs,
            context: context
        )
        return result
    }

    /// Presents the UIActivityViewController and returns the result.
    @MainActor
    private func presentShareSheet(
        items: [Any],
        title: String?,
        temporaryFileURLs: [URL],
        context: ModuleContext
    ) async throws -> AnyCodable {
        guard let viewController = context.viewController as? UIViewController else {
            cleanupTemporaryFiles(temporaryFileURLs)
            throw BridgeError.invalidPayload("No view controller available to present share sheet")
        }

        return await withCheckedContinuation { continuation in
            let activityVC = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )

            // Set subject for email sharing
            if let title {
                activityVC.setValue(title, forKey: "subject")
            }

            // Configure for iPad - present from center of screen
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(
                    x: viewController.view.bounds.midX,
                    y: viewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            // Handle completion
            activityVC.completionWithItemsHandler = { [temporaryFileURLs] activityType, completed, _, error in
                // Clean up temporary files
                self.cleanupTemporaryFiles(temporaryFileURLs)

                if let error {
                    continuation.resume(returning: AnyCodable([
                        "shared": AnyCodable(false),
                        "error": AnyCodable(error.localizedDescription),
                    ]))
                } else if completed {
                    var result: [String: AnyCodable] = ["shared": AnyCodable(true)]
                    if let activityType {
                        result["activityType"] = AnyCodable(activityType.rawValue)
                    }
                    continuation.resume(returning: AnyCodable(result))
                } else {
                    continuation.resume(returning: AnyCodable([
                        "shared": AnyCodable(false),
                        "cancelled": AnyCodable(true),
                    ]))
                }
            }

            viewController.present(activityVC, animated: true)
        }
    }

    /// Cleans up temporary files created for sharing.
    ///
    /// - Parameter urls: Array of temporary file URLs to delete.
    private func cleanupTemporaryFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
            // Also try to remove the parent directory if empty
            let parentDir = url.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: parentDir)
        }
    }

    // MARK: - Can Share Action

    /// Handles the `canShare` action to check if sharing is available.
    ///
    /// - Parameter payload: Optional dictionary with data types to check (currently unused).
    /// - Returns: A dictionary with `canShare: true` if sharing is available.
    private func handleCanShare(payload _: AnyCodable?) -> AnyCodable {
        AnyCodable([
            "available": AnyCodable(true),
        ])
    }
}
