import Combine
import Foundation
import UIKit
import WebKit

// MARK: - KeyboardHandler

/// Handles keyboard dismiss events to prevent layout glitches in WKWebView.
///
/// `KeyboardHandler` observes the `keyboardWillHide` notification and triggers
/// a layout update on the attached WKWebView. This prevents visual glitches that
/// can occur when the keyboard dismisses and the webview doesn't properly update
/// its layout.
///
/// ## Why This Is Needed
///
/// When the iOS keyboard dismisses, WKWebView sometimes experiences layout issues
/// where the content doesn't properly reposition. This handler forces a layout
/// pass when the keyboard hides, ensuring smooth visual transitions.
///
/// ## How It Works
///
/// When attached to a WKWebView:
/// 1. The handler observes `UIResponder.keyboardWillHideNotification`
/// 2. When the keyboard begins to hide, it triggers `setNeedsLayout()` on the WebView
/// 3. It then calls `layoutIfNeeded()` to immediately perform the layout pass
///
/// ## Usage
///
/// ```swift
/// let keyboardHandler = KeyboardHandler()
///
/// // Attach to a WebView
/// keyboardHandler.attach(to: webView)
///
/// // Optionally subscribe to keyboard hide events
/// keyboardHandler.keyboardWillHidePublisher
///     .sink { print("Keyboard will hide") }
///     .store(in: &cancellables)
///
/// // Later, when done:
/// keyboardHandler.detach()
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated as it interacts with UIKit components.
@MainActor
public final class KeyboardHandler {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a new keyboard handler.
    public init() {}

    deinit {
        MainActor.assumeIsolated {
            detach()
        }
    }

    // MARK: Public

    // MARK: - Publishers

    /// Publishes when the keyboard will hide.
    ///
    /// Use this to perform additional actions when the keyboard dismisses,
    /// such as adjusting UI elements or logging.
    public var keyboardWillHidePublisher: AnyPublisher<Void, Never> {
        keyboardWillHideSubject.eraseToAnyPublisher()
    }

    // MARK: - State

    /// Whether the handler is currently attached to a WebView.
    public var isAttached: Bool {
        attachedWebView != nil
    }

    // MARK: - Public API

    /// Attaches the keyboard handler to a WKWebView.
    ///
    /// This method sets up observation of keyboard hide notifications and
    /// configures the handler to trigger layout updates on the WebView.
    /// If already attached to another WebView, it will detach first.
    ///
    /// - Parameter webView: The WKWebView to attach to.
    public func attach(to webView: WKWebView) {
        // Detach from any existing WebView first
        if attachedWebView != nil {
            detach()
        }

        attachedWebView = webView

        // Observe keyboard will hide notification
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleKeyboardWillHide()
            }
        }
    }

    /// Detaches the keyboard handler from the current WebView.
    ///
    /// This method removes the keyboard notification observer and cleans up
    /// internal state.
    public func detach() {
        // Remove notification observer
        if let observer = keyboardObserver {
            NotificationCenter.default.removeObserver(observer)
            keyboardObserver = nil
        }

        attachedWebView = nil
    }

    // MARK: Private

    // MARK: - Private Properties

    /// Weak reference to the attached WebView.
    private weak var attachedWebView: WKWebView?

    /// Subject for publishing keyboard hide events.
    private let keyboardWillHideSubject = PassthroughSubject<Void, Never>()

    /// Storage for the notification observer.
    private var keyboardObserver: NSObjectProtocol?

    // MARK: - Private Methods

    /// Handles the keyboard will hide notification.
    ///
    /// Triggers a layout update on the attached WebView to prevent
    /// layout glitches when the keyboard dismisses.
    private func handleKeyboardWillHide() {
        guard let webView = attachedWebView else { return }

        // Publish the event
        keyboardWillHideSubject.send()

        // Trigger layout update on the WebView to prevent glitches
        webView.setNeedsLayout()
        webView.layoutIfNeeded()

        // Also update the scroll view layout
        webView.scrollView.setNeedsLayout()
        webView.scrollView.layoutIfNeeded()
    }
}

// MARK: - Convenience Extensions

extension KeyboardHandler {
    /// Creates and attaches a keyboard handler to a WebView.
    ///
    /// This is a convenience method for creating and immediately attaching
    /// a handler in one step.
    ///
    /// - Parameter webView: The WKWebView to attach to.
    /// - Returns: The configured and attached handler.
    public static func attached(to webView: WKWebView) -> KeyboardHandler {
        let handler = KeyboardHandler()
        handler.attach(to: webView)
        return handler
    }
}
