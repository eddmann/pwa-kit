import Foundation
import UIKit
import WebKit

// MARK: - BridgeScriptMessageHandler

/// WKScriptMessageHandler implementation that bridges JavaScript messages to Swift.
///
/// `BridgeScriptMessageHandler` conforms to `WKScriptMessageHandler` and serves as
/// the entry point for all JavaScript-to-Swift bridge communication. It:
/// - Receives messages from JavaScript via `window.webkit.messageHandlers.pwakit.postMessage()`
/// - Parses incoming JSON messages
/// - Routes them to the `BridgeDispatcher` for handling
/// - Sends responses back to JavaScript via `evaluateJavaScript`
///
/// ## Setup
///
/// Register the handler with a WKWebView configuration:
///
/// ```swift
/// let dispatcher = BridgeDispatcher()
/// await dispatcher.register(PlatformModule())
///
/// let handler = BridgeScriptMessageHandler(dispatcher: dispatcher)
/// let config = WebViewConfigurationFactory.makeConfiguration(
///     webViewConfiguration: webViewConfig,
///     messageHandler: handler
/// )
/// let webView = WKWebView(frame: .zero, configuration: config)
/// handler.webView = webView
/// ```
///
/// ## JavaScript Usage
///
/// From JavaScript, send messages to the bridge:
///
/// ```javascript
/// window.webkit.messageHandlers.pwakit.postMessage(JSON.stringify({
///   id: "abc-123",
///   module: "platform",
///   action: "getInfo"
/// }));
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated since WKWebView and WKScriptMessageHandler
/// operations must occur on the main thread. The dispatcher is an actor, so
/// communication with it is safe across concurrency boundaries.
@MainActor
public final class BridgeScriptMessageHandler: NSObject, WKScriptMessageHandler {
    /// The dispatcher that handles incoming messages.
    private let dispatcher: BridgeDispatcher

    /// The module context factory for creating contexts for each request.
    private let contextFactory: ModuleContextFactory

    /// Weak reference to the web view for sending responses.
    ///
    /// This must be set after the WKWebView is created since the handler
    /// is required during configuration creation.
    public weak var webView: WKWebView?

    /// Weak reference to the view controller for UI presentation in modules.
    public weak var viewController: UIViewController?

    /// The app configuration for module context.
    public var configuration: PWAConfiguration

    /// Creates a new bridge script message handler.
    ///
    /// - Parameters:
    ///   - dispatcher: The bridge dispatcher to route messages to.
    ///   - configuration: The app configuration. Defaults to `.default`.
    public init(
        dispatcher: BridgeDispatcher,
        configuration: PWAConfiguration = .default
    ) {
        self.dispatcher = dispatcher
        self.configuration = configuration
        self.contextFactory = ModuleContextFactory()
        super.init()
    }

    /// Creates a new bridge script message handler with a custom context factory.
    ///
    /// This initializer is primarily for testing purposes.
    ///
    /// - Parameters:
    ///   - dispatcher: The bridge dispatcher to route messages to.
    ///   - configuration: The app configuration.
    ///   - contextFactory: Custom factory for creating module contexts.
    init(
        dispatcher: BridgeDispatcher,
        configuration: PWAConfiguration,
        contextFactory: ModuleContextFactory
    ) {
        self.dispatcher = dispatcher
        self.configuration = configuration
        self.contextFactory = contextFactory
        super.init()
    }

    // MARK: - WKScriptMessageHandler

    /// Handles incoming script messages from JavaScript.
    ///
    /// This method is called by WebKit when JavaScript invokes
    /// `window.webkit.messageHandlers.pwakit.postMessage()`.
    ///
    /// - Parameters:
    ///   - userContentController: The user content controller that received the message.
    ///   - message: The script message containing the bridge request.
    public func userContentController(
        _: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Extract the message body as a string
        guard let jsonString = extractJSONString(from: message.body) else {
            sendErrorResponse(
                id: "parse-error",
                error: "Invalid message format: expected JSON string"
            )
            return
        }

        // Process the message asynchronously
        Task { @MainActor in
            await processMessage(jsonString)
        }
    }

    // MARK: - Message Processing

    /// Processes a JSON message string through the dispatcher.
    ///
    /// - Parameter jsonString: The JSON-encoded bridge message.
    private func processMessage(_ jsonString: String) async {
        // Create the module context
        let context = contextFactory.makeContext(
            webView: webView,
            viewController: viewController,
            configuration: configuration
        )

        // Dispatch the message and get the response
        let responseJSON = await dispatcher.dispatch(jsonString: jsonString, context: context)

        // Send the response back to JavaScript
        sendResponse(responseJSON)
    }

    // MARK: - Response Sending

    /// Sends a JSON response back to JavaScript.
    ///
    /// - Parameter jsonString: The JSON-encoded response string.
    private func sendResponse(_ jsonString: String) {
        guard let webView else {
            // No web view available to send response
            return
        }

        let javascript = JavaScriptBridge.formatCallback(jsonString: jsonString)
        webView.evaluateJavaScript(javascript) { _, error in
            if let error {
                // Log error but don't propagate - we can't do much about it
                #if DEBUG
                    print("[BridgeScriptMessageHandler] Error sending response: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Sends an error response back to JavaScript.
    ///
    /// - Parameters:
    ///   - id: The request ID (or a fallback ID for parse errors).
    ///   - error: The error message.
    private func sendErrorResponse(id: String, error: String) {
        let response = BridgeResponse.failure(id: id, error: error)
        let javascript = JavaScriptBridge.formatCallback(response)

        guard let webView else { return }

        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    // MARK: - Private Helpers

    /// Extracts a JSON string from the message body.
    ///
    /// The message body can be either a String (if JavaScript passed a JSON string)
    /// or a dictionary (if JavaScript passed an object directly).
    ///
    /// - Parameter body: The message body from WKScriptMessage.
    /// - Returns: A JSON string, or nil if extraction fails.
    private func extractJSONString(from body: Any) -> String? {
        // If it's already a string, return it directly
        if let jsonString = body as? String {
            return jsonString
        }

        // If it's a dictionary or array, encode it to JSON
        if JSONSerialization.isValidJSONObject(body) {
            do {
                let data = try JSONSerialization.data(withJSONObject: body)
                return String(data: data, encoding: .utf8)
            } catch {
                return nil
            }
        }

        return nil
    }
}

// MARK: - ModuleContextFactory

/// Factory for creating `ModuleContext` instances.
///
/// This factory is separated to enable testing with mock contexts.
@MainActor
public final class ModuleContextFactory {
    /// Creates a new module context factory.
    public init() {}

    /// Creates a module context with the given parameters.
    ///
    /// - Parameters:
    ///   - webView: The web view for JavaScript evaluation.
    ///   - viewController: The view controller for UI presentation.
    ///   - configuration: The app configuration.
    /// - Returns: A configured module context.
    public func makeContext(
        webView: AnyObject?,
        viewController: AnyObject?,
        configuration: PWAConfiguration
    ) -> ModuleContext {
        ModuleContext(
            webView: webView,
            viewController: viewController,
            configuration: configuration
        )
    }
}

// MARK: - Convenience Extensions

extension BridgeScriptMessageHandler {
    /// Sends a bridge event to JavaScript.
    ///
    /// Use this method to send unsolicited events from native code to the web layer,
    /// such as push notification delivery or lifecycle events.
    ///
    /// - Parameter event: The event to send.
    public func sendEvent(_ event: BridgeEvent) {
        guard let webView else { return }

        let javascript = JavaScriptBridge.formatEvent(event)
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }

    /// Sends a bridge event to JavaScript with type and data.
    ///
    /// - Parameters:
    ///   - type: The event type (e.g., "push", "lifecycle").
    ///   - data: The event data payload.
    public func sendEvent(type: String, data: AnyCodable? = nil) {
        let event = BridgeEvent(type: type, data: data)
        sendEvent(event)
    }
}
