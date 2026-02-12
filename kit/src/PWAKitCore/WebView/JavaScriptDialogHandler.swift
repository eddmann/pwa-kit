import Foundation
import UIKit
import WebKit

/// WKUIDelegate implementation for handling JavaScript dialogs.
///
/// `JavaScriptDialogHandler` provides native UIAlertController-based implementations
/// for JavaScript dialog methods (`alert()`, `confirm()`, `prompt()`). Without a
/// WKUIDelegate, these dialogs are silently ignored by WKWebView.
///
/// ## Usage
///
/// Set this handler as the UI delegate for your WKWebView:
///
/// ```swift
/// let dialogHandler = JavaScriptDialogHandler()
/// dialogHandler.viewController = myViewController
/// webView.uiDelegate = dialogHandler
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated since all WKUIDelegate methods and
/// UIAlertController presentations must occur on the main thread.
@MainActor
public final class JavaScriptDialogHandler: NSObject, WKUIDelegate {
    /// The view controller used to present alert dialogs.
    ///
    /// This must be set to a valid view controller for dialogs to appear.
    /// If not set, completion handlers will be called immediately with default values.
    public weak var viewController: UIViewController?

    /// Creates a new JavaScript dialog handler.
    ///
    /// - Parameter viewController: The view controller to present dialogs on.
    ///   Can also be set after initialization via the property.
    public init(viewController: UIViewController? = nil) {
        self.viewController = viewController
        super.init()
    }

    // MARK: - WKUIDelegate - JavaScript Alert

    /// Handles JavaScript `alert()` calls by presenting a native UIAlertController.
    ///
    /// The alert displays the message from JavaScript with a single "OK" button.
    /// The completion handler is called when the user dismisses the alert.
    ///
    /// - Parameters:
    ///   - webView: The web view invoking the delegate method.
    ///   - message: The message to display in the alert.
    ///   - frame: Information about the frame that initiated the alert.
    ///   - completionHandler: A closure to call when the alert is dismissed.
    public func webView(
        _: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        guard let presenter = viewController else {
            // No presenter available, dismiss silently
            completionHandler()
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(
            title: NSLocalizedString("OK", comment: "Alert dialog OK button"),
            style: .default
        ) { _ in
            completionHandler()
        }

        alert.addAction(okAction)

        presenter.present(alert, animated: true)
    }

    // MARK: - WKUIDelegate - JavaScript Confirm

    /// Handles JavaScript `confirm()` calls by presenting a native UIAlertController.
    ///
    /// The confirm dialog displays the message from JavaScript with "Cancel" and "OK" buttons.
    /// The completion handler is called with `true` if the user taps "OK", or `false` if
    /// the user taps "Cancel" or dismisses the dialog.
    ///
    /// - Parameters:
    ///   - webView: The web view invoking the delegate method.
    ///   - message: The message to display in the confirm dialog.
    ///   - frame: Information about the frame that initiated the confirm.
    ///   - completionHandler: A closure to call with the user's response (`true` for OK, `false` for Cancel).
    public func webView(
        _: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let presenter = viewController else {
            // No presenter available, return false (cancel)
            completionHandler(false)
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: "Confirm dialog Cancel button"),
            style: .cancel
        ) { _ in
            completionHandler(false)
        }

        let okAction = UIAlertAction(
            title: NSLocalizedString("OK", comment: "Confirm dialog OK button"),
            style: .default
        ) { _ in
            completionHandler(true)
        }

        alert.addAction(cancelAction)
        alert.addAction(okAction)

        presenter.present(alert, animated: true)
    }

    // MARK: - WKUIDelegate - JavaScript Prompt

    /// Handles JavaScript `prompt()` calls by presenting a native UIAlertController with a text field.
    ///
    /// The prompt dialog displays the message from JavaScript with a text input field,
    /// "Cancel" and "OK" buttons. The completion handler is called with the entered text
    /// if the user taps "OK", or `nil` if the user taps "Cancel" or dismisses the dialog.
    ///
    /// - Parameters:
    ///   - webView: The web view invoking the delegate method.
    ///   - prompt: The message to display in the prompt dialog.
    ///   - defaultText: The default text to display in the text field, if any.
    ///   - frame: Information about the frame that initiated the prompt.
    ///   - completionHandler: A closure to call with the user's input (the entered string or `nil` if cancelled).
    public func webView(
        _: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        guard let presenter = viewController else {
            // No presenter available, return nil (cancel)
            completionHandler(nil)
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: prompt,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.text = defaultText
        }

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: "Prompt dialog Cancel button"),
            style: .cancel
        ) { _ in
            completionHandler(nil)
        }

        let okAction = UIAlertAction(
            title: NSLocalizedString("OK", comment: "Prompt dialog OK button"),
            style: .default
        ) { _ in
            let enteredText = alert.textFields?.first?.text
            completionHandler(enteredText)
        }

        alert.addAction(cancelAction)
        alert.addAction(okAction)

        presenter.present(alert, animated: true)
    }

    // MARK: - WKUIDelegate - New Window Handling

    /// Handles requests to create a new web view (e.g., target="_blank" links, window.open()).
    ///
    /// Instead of opening a new window, this loads the URL in the existing webview,
    /// maintaining the single-view PWA experience.
    ///
    /// - Parameters:
    ///   - webView: The web view requesting a new window.
    ///   - configuration: The configuration for the new web view.
    ///   - navigationAction: The navigation action that triggered the request.
    ///   - windowFeatures: The window features requested by the content.
    /// - Returns: Always `nil` to prevent creating a new window.
    public func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        // If targetFrame is nil, this is a new window request (target="_blank" or window.open())
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil // Don't create a new webview, keep single-view PWA experience
    }
}
