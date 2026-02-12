import Foundation
import UIKit
import WebKit

// MARK: - PrintModule

/// A module that provides native printing capabilities to JavaScript.
///
/// `PrintModule` exposes iOS AirPrint functionality to web applications,
/// allowing them to print the current webview content.
///
/// ## Supported Actions
///
/// - `print`: Print the current webview content using AirPrint.
///   - `jobName`: Optional job name to display in the print queue.
///
/// - `canPrint`: Check if printing is available on this device.
///   - Returns `{ canPrint: true/false }`
///
/// ## Example
///
/// JavaScript request to print:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "print",
///   "action": "print",
///   "payload": {
///     "jobName": "My Document"
///   }
/// }
/// ```
///
/// Response on success:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "printed": true }
/// }
/// ```
///
/// Response when user cancelled:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": { "printed": false, "cancelled": true }
/// }
/// ```
public struct PrintModule: PWAModule {
    public static let moduleName = "print"
    public static let supportedActions = ["print", "canPrint"]

    /// Creates a new print module instance.
    public init() {}

    public func handle(
        action: String,
        payload: AnyCodable?,
        context: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "print":
            return try await handlePrint(payload: payload, context: context)

        case "canPrint":
            return handleCanPrint()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Print Action

    /// Handles the `print` action to present the print dialog.
    ///
    /// - Parameters:
    ///   - payload: Optional dictionary containing print options.
    ///     - `jobName`: Optional string for the print job name.
    ///   - context: The module context containing webview reference.
    /// - Returns: A dictionary with `printed: true/false` and optionally `cancelled: true`.
    /// - Throws: `BridgeError.invalidPayload` if webview is unavailable.
    private func handlePrint(payload: AnyCodable?, context: ModuleContext) async throws -> AnyCodable {
        let jobName = payload?["jobName"]?.stringValue
        return try await presentPrintDialog(jobName: jobName, context: context)
    }

    /// Presents the UIPrintInteractionController and returns the result.
    @MainActor
    private func presentPrintDialog(
        jobName: String?,
        context: ModuleContext
    ) async throws -> AnyCodable {
        guard let webView = context.webView as? WKWebView else {
            throw BridgeError.invalidPayload("No webview available for printing")
        }

        guard UIPrintInteractionController.isPrintingAvailable else {
            return AnyCodable([
                "printed": AnyCodable(false),
                "error": AnyCodable("Printing is not available"),
            ])
        }

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()

        // Configure print job
        printInfo.outputType = .general
        if let jobName {
            printInfo.jobName = jobName
        } else {
            printInfo.jobName = "Web Page"
        }

        printController.printInfo = printInfo
        printController.printFormatter = webView.viewPrintFormatter()

        return await withCheckedContinuation { continuation in
            printController.present(animated: true) { _, completed, error in
                if let error {
                    continuation.resume(returning: AnyCodable([
                        "printed": AnyCodable(false),
                        "error": AnyCodable(error.localizedDescription),
                    ]))
                } else if completed {
                    continuation.resume(returning: AnyCodable([
                        "printed": AnyCodable(true),
                    ]))
                } else {
                    continuation.resume(returning: AnyCodable([
                        "printed": AnyCodable(false),
                        "cancelled": AnyCodable(true),
                    ]))
                }
            }
        }
    }

    // MARK: - Can Print Action

    /// Handles the `canPrint` action to check if printing is available.
    ///
    /// - Returns: A dictionary with `canPrint: true` if printing is available.
    private func handleCanPrint() -> AnyCodable {
        AnyCodable([
            "canPrint": AnyCodable(UIPrintInteractionController.isPrintingAvailable),
        ])
    }
}
