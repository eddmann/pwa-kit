import Combine
import Foundation
import UIKit
import WebKit

// MARK: - PullToRefreshHandler

/// Handles pull-to-refresh gesture for WKWebView.
///
/// `PullToRefreshHandler` adds a `UIRefreshControl` to the WebView's scroll view,
/// allowing users to pull down to reload the page. This is a common pattern in
/// native iOS apps and provides a familiar interaction for refreshing content.
///
/// ## How It Works
///
/// When attached to a WKWebView:
/// 1. A `UIRefreshControl` is added to the WebView's `scrollView`
/// 2. When the user pulls down past the threshold, the refresh control activates
/// 3. The handler triggers a reload on the WebView
/// 4. After the reload starts, the refresh control is dismissed
///
/// ## Usage
///
/// ```swift
/// let pullToRefresh = PullToRefreshHandler()
///
/// // Attach to a WebView
/// pullToRefresh.attach(to: webView)
///
/// // Optionally subscribe to refresh events
/// pullToRefresh.didRefreshPublisher
///     .sink { print("User triggered refresh") }
///     .store(in: &cancellables)
///
/// // Later, when done:
/// pullToRefresh.detach()
/// ```
///
/// ## Platform Availability
///
/// This handler is **not available on macCatalyst** as pull-to-refresh is not
/// a standard interaction pattern on Mac. The entire type is excluded from
/// macCatalyst builds via conditional compilation.
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated as it interacts with UIKit components.
@MainActor
public final class PullToRefreshHandler {
    // MARK: - Publishers

    /// Publishes when a refresh is triggered by the user.
    ///
    /// Use this to perform additional actions when the user pulls to refresh,
    /// such as logging or analytics.
    public var didRefreshPublisher: AnyPublisher<Void, Never> {
        didRefreshSubject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    /// Whether pull-to-refresh is enabled.
    ///
    /// When set to `false`, the refresh control is hidden and the gesture
    /// is disabled. Default is `true`.
    public var isEnabled = true {
        didSet {
            refreshControl?.isEnabled = isEnabled
            if !isEnabled {
                refreshControl?.isHidden = true
            } else if refreshControl != nil {
                refreshControl?.isHidden = false
            }
        }
    }

    /// The tint color for the refresh control spinner.
    ///
    /// Set this to match your app's theme. If `nil`, the system default is used.
    public var tintColor: UIColor? {
        didSet {
            refreshControl?.tintColor = tintColor
        }
    }

    /// The attributed title shown below the spinner during refresh.
    ///
    /// Set this to provide feedback like "Updating..." to the user.
    /// If `nil`, no title is shown.
    public var attributedTitle: NSAttributedString? {
        didSet {
            refreshControl?.attributedTitle = attributedTitle
        }
    }

    // MARK: - State

    /// Whether the refresh control is currently refreshing.
    public var isRefreshing: Bool {
        refreshControl?.isRefreshing ?? false
    }

    /// Whether the handler is currently attached to a WebView.
    public var isAttached: Bool {
        attachedWebView != nil
    }

    // MARK: - Private Properties

    /// The refresh control added to the WebView's scroll view.
    private var refreshControl: UIRefreshControl?

    /// Weak reference to the attached WebView.
    private weak var attachedWebView: WKWebView?

    /// Subject for publishing refresh events.
    private let didRefreshSubject = PassthroughSubject<Void, Never>()

    // MARK: - Initialization

    /// Creates a new pull-to-refresh handler.
    ///
    /// - Parameters:
    ///   - isEnabled: Whether pull-to-refresh is initially enabled. Default is `true`.
    ///   - tintColor: The tint color for the spinner. Default is `nil` (system default).
    public init(isEnabled: Bool = true, tintColor: UIColor? = nil) {
        self.isEnabled = isEnabled
        self.tintColor = tintColor
    }

    deinit {
        MainActor.assumeIsolated {
            detach()
        }
    }

    // MARK: - Public API

    /// Attaches the pull-to-refresh handler to a WKWebView.
    ///
    /// This method adds a `UIRefreshControl` to the WebView's scroll view.
    /// If already attached to another WebView, it will detach first.
    ///
    /// - Parameter webView: The WKWebView to attach to.
    public func attach(to webView: WKWebView) {
        // Detach from any existing WebView first
        if attachedWebView != nil {
            detach()
        }

        attachedWebView = webView

        // Create and configure the refresh control
        let control = UIRefreshControl()
        control.isEnabled = isEnabled
        control.isHidden = !isEnabled
        control.tintColor = tintColor
        control.attributedTitle = attributedTitle
        control.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)

        // Add to the scroll view and enable bounces (required for pull-to-refresh gesture)
        webView.scrollView.bounces = true
        webView.scrollView.refreshControl = control
        refreshControl = control
    }

    /// Detaches the pull-to-refresh handler from the current WebView.
    ///
    /// This method removes the `UIRefreshControl` from the WebView's scroll view
    /// and cleans up internal state.
    public func detach() {
        refreshControl?.endRefreshing()
        refreshControl?.removeTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)

        // Remove from scroll view
        attachedWebView?.scrollView.refreshControl = nil

        refreshControl = nil
        attachedWebView = nil
    }

    /// Programmatically triggers a refresh.
    ///
    /// This method shows the refresh control animation and reloads the WebView,
    /// just as if the user had pulled to refresh.
    public func beginRefreshing() {
        guard let webView = attachedWebView, let control = refreshControl else { return }

        control.beginRefreshing()
        webView.reload()
        didRefreshSubject.send()

        // End refreshing after a short delay to show the animation
        endRefreshingAfterDelay()
    }

    /// Ends the refresh animation if currently refreshing.
    ///
    /// Call this if you need to programmatically stop the refresh animation
    /// without waiting for the automatic dismissal.
    public func endRefreshing() {
        refreshControl?.endRefreshing()
    }

    // MARK: - Private Methods

    /// Handles the pull-to-refresh gesture.
    ///
    /// - Parameter sender: The refresh control that triggered the action.
    @objc private func handleRefresh(_ sender: UIRefreshControl) {
        guard let webView = attachedWebView else {
            sender.endRefreshing()
            return
        }

        // Reload the WebView
        webView.reload()

        // Publish the refresh event
        didRefreshSubject.send()

        // End refreshing after a short delay
        endRefreshingAfterDelay()
    }

    /// Ends the refresh animation after a short delay.
    ///
    /// This provides visual feedback that the refresh was triggered before
    /// immediately dismissing the spinner.
    private func endRefreshingAfterDelay() {
        Task { @MainActor [weak self] in
            // Small delay to show the refresh animation
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            self?.refreshControl?.endRefreshing()
        }
    }
}

// MARK: - Convenience Extensions

extension PullToRefreshHandler {
    /// Creates and attaches a pull-to-refresh handler to a WebView.
    ///
    /// This is a convenience method for creating and immediately attaching
    /// a handler in one step.
    ///
    /// - Parameters:
    ///   - webView: The WKWebView to attach to.
    ///   - isEnabled: Whether pull-to-refresh is enabled. Default is `true`.
    ///   - tintColor: The tint color for the spinner. Default is `nil`.
    /// - Returns: The configured and attached handler.
    public static func attached(
        to webView: WKWebView,
        isEnabled: Bool = true,
        tintColor: UIColor? = nil
    ) -> PullToRefreshHandler {
        let handler = PullToRefreshHandler(isEnabled: isEnabled, tintColor: tintColor)
        handler.attach(to: webView)
        return handler
    }
}
