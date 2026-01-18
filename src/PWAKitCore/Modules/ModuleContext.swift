import Foundation

// MARK: - ModuleContext

/// Context provided to modules when handling requests.
///
/// `ModuleContext` provides modules with access to shared app resources
/// needed to perform their operations. This includes references to the
/// web view for JavaScript evaluation, the presenting view controller
/// for UI presentation, and the app configuration.
///
/// ## Thread Safety
///
/// `ModuleContext` is `Sendable` and can be safely passed between
/// concurrency domains. The weak references ensure no retain cycles
/// with UIKit objects. The configuration is a value type and is
/// always safe to access.
///
/// ## Example
///
/// ```swift
/// func handle(
///     action: String,
///     payload: AnyCodable?,
///     context: ModuleContext
/// ) async throws -> AnyCodable? {
///     // Access the view controller for UI presentation
///     guard let viewController = await context.viewController else {
///         throw BridgeError.invalidPayload("No view controller available")
///     }
///
///     // Check feature flags from configuration
///     if context.configuration.features.haptics {
///         // Haptics are enabled
///     }
///
///     // Present a share sheet
///     await MainActor.run {
///         viewController.present(activityVC, animated: true)
///     }
/// }
/// ```
public struct ModuleContext: Sendable {
    /// Weak reference holder for UIKit objects.
    ///
    /// This wrapper enables storing weak references in a Sendable struct
    /// by isolating the reference to the main actor.
    @MainActor
    public final class WeakReference<T: AnyObject>: @unchecked Sendable {
        /// The weakly-held value.
        public weak var value: T?

        /// Creates a weak reference to the given value.
        ///
        /// - Parameter value: The object to hold weakly.
        public init(_ value: T?) {
            self.value = value
        }
    }

    /// Weak reference to the WKWebView for JavaScript evaluation.
    ///
    /// Use the `webView` property to access the web view.
    /// The type is `AnyObject` to avoid importing WebKit at this layer.
    private let _webView: WeakReference<AnyObject>

    /// Weak reference to the presenting view controller for UI presentation.
    ///
    /// Use the `viewController` property to access the view controller.
    /// The type is `AnyObject` to avoid importing UIKit at this layer.
    private let _viewController: WeakReference<AnyObject>

    /// The app configuration snapshot.
    ///
    /// This is a copy of the configuration at the time the context was created.
    /// Modules can use this to check feature flags and access app settings
    /// without additional async calls.
    public let configuration: PWAConfiguration

    /// Creates a new module context.
    ///
    /// - Parameters:
    ///   - webView: The WKWebView instance (or nil). Pass as `AnyObject` to avoid
    ///              importing WebKit. The caller is responsible for ensuring this
    ///              is actually a `WKWebView`.
    ///   - viewController: The presenting UIViewController (or nil). Pass as `AnyObject`
    ///                     to avoid importing UIKit. The caller is responsible for
    ///                     ensuring this is actually a `UIViewController`.
    ///   - configuration: The app configuration. Defaults to a minimal default
    ///                    configuration for testing purposes.
    @MainActor
    public init(
        webView: AnyObject? = nil,
        viewController: AnyObject? = nil,
        configuration: PWAConfiguration = .default
    ) {
        self._webView = WeakReference(webView)
        self._viewController = WeakReference(viewController)
        self.configuration = configuration
    }

    /// The WKWebView for JavaScript evaluation, if available.
    ///
    /// Returns `nil` if the web view has been deallocated or was never set.
    /// The caller should cast this to `WKWebView` for use.
    @MainActor
    public var webView: AnyObject? {
        _webView.value
    }

    /// The presenting view controller for UI presentation, if available.
    ///
    /// Returns `nil` if the view controller has been deallocated or was never set.
    /// The caller should cast this to `UIViewController` for use.
    @MainActor
    public var viewController: AnyObject? {
        _viewController.value
    }
}

// MARK: - PWAConfiguration Default Extension

extension PWAConfiguration {
    /// A minimal default configuration for testing and fallback purposes.
    ///
    /// This configuration uses placeholder values and is primarily intended
    /// for unit testing modules without requiring a full configuration setup.
    public static let `default` = PWAConfiguration(
        version: 1,
        app: AppConfiguration(
            name: "PWAKit",
            bundleId: "com.pwakit.app",
            startUrl: "https://localhost/"
        ),
        origins: OriginsConfiguration(
            allowed: ["localhost"],
            auth: [],
            external: []
        ),
        features: .default,
        appearance: .default,
        notifications: .default
    )
}
