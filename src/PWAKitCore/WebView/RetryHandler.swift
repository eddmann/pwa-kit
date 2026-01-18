import Combine
import Foundation
import WebKit

// MARK: - RetryHandler

/// Handles automatic retry logic for WKWebView navigation failures.
///
/// `RetryHandler` detects provisional navigation failures and schedules automatic
/// retries after a configurable delay. It ignores cancelled navigation errors
/// (error code -999) which occur when the user navigates away during loading.
///
/// ## How It Works
///
/// When a navigation failure is reported:
/// 1. The handler checks if it's a cancelled error (-999) and ignores it
/// 2. If not cancelled, it starts a countdown timer
/// 3. During the countdown, `retryProgressPublisher` emits progress updates
/// 4. After the delay, `shouldRetryPublisher` emits `true`
/// 5. The consumer can then reload the WebView
///
/// ## Usage
///
/// ```swift
/// let retryHandler = RetryHandler()
///
/// // Subscribe to retry signals
/// retryHandler.shouldRetryPublisher
///     .sink { shouldRetry in
///         if shouldRetry {
///             webView.reload()
///         }
///     }
///     .store(in: &cancellables)
///
/// // Subscribe to progress for UI updates
/// retryHandler.retryProgressPublisher
///     .sink { progress in
///         errorView.retryProgress = progress
///     }
///     .store(in: &cancellables)
///
/// // Report navigation failures
/// func webView(_ webView: WKWebView, didFailProvisionalNavigation: ..., withError error: Error) {
///     retryHandler.handleNavigationFailure(error: error)
/// }
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated as it interacts with UI components
/// and must coordinate with WKWebView operations.
@MainActor
public final class RetryHandler {
    // MARK: - Constants

    /// The NSURLError code for cancelled requests.
    private static let cancelledErrorCode = -999

    // MARK: - Publishers

    /// Publishes `true` when a retry should be attempted.
    ///
    /// Emits once after the retry delay has elapsed following a navigation failure.
    /// The consumer should reload the WebView when this emits `true`.
    public var shouldRetryPublisher: AnyPublisher<Bool, Never> {
        shouldRetrySubject.eraseToAnyPublisher()
    }

    /// Publishes the progress towards the next retry (0.0 to 1.0).
    ///
    /// Use this to update a progress indicator in the error view.
    /// Progress updates occur roughly every 100ms during the countdown.
    public var retryProgressPublisher: AnyPublisher<Double, Never> {
        retryProgressSubject.eraseToAnyPublisher()
    }

    /// Publishes whether there is currently a failure requiring retry.
    ///
    /// Use this to show/hide the error view.
    public var hasFailurePublisher: AnyPublisher<Bool, Never> {
        hasFailureSubject.eraseToAnyPublisher()
    }

    // MARK: - Current State

    /// Whether there is currently a failure pending retry.
    public private(set) var hasFailure = false {
        didSet {
            hasFailureSubject.send(hasFailure)
        }
    }

    /// The current progress towards retry (0.0 to 1.0).
    public private(set) var retryProgress = 0.0 {
        didSet {
            retryProgressSubject.send(retryProgress)
        }
    }

    /// The most recent error that triggered a retry.
    public private(set) var lastError: Error?

    // MARK: - Configuration

    /// The delay (in seconds) before attempting a retry.
    ///
    /// Default is 6.0 seconds.
    public var retryDelay: TimeInterval = 6.0

    /// The interval (in seconds) between progress updates.
    ///
    /// Default is 0.1 seconds (100ms).
    public var progressUpdateInterval: TimeInterval = 0.1

    // MARK: - Private Properties

    /// Subject for publishing retry signals.
    private let shouldRetrySubject = PassthroughSubject<Bool, Never>()

    /// Subject for publishing retry progress.
    private let retryProgressSubject = CurrentValueSubject<Double, Never>(0.0)

    /// Subject for publishing failure state.
    private let hasFailureSubject = CurrentValueSubject<Bool, Never>(false)

    /// Task for the retry countdown.
    private var retryTask: Task<Void, Never>?

    /// Task for progress updates during countdown.
    private var progressTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new retry handler.
    ///
    /// - Parameter retryDelay: The delay before attempting retry. Default is 6.0 seconds.
    public init(retryDelay: TimeInterval = 6.0) {
        self.retryDelay = retryDelay
    }

    deinit {
        MainActor.assumeIsolated {
            cancel()
        }
    }

    // MARK: - Public API

    /// Reports a navigation failure and schedules a retry.
    ///
    /// If the error is a cancelled navigation (error code -999), it will be ignored.
    /// Otherwise, a retry will be scheduled after the configured delay.
    ///
    /// - Parameter error: The navigation error that occurred.
    public func handleNavigationFailure(error: Error) {
        // Ignore cancelled navigations
        let nsError = error as NSError
        if nsError.code == Self.cancelledErrorCode {
            return
        }

        // Cancel any existing retry
        cancel()

        // Store the error and update state
        lastError = error
        hasFailure = true
        retryProgress = 0.0

        // Start countdown
        startRetryCountdown()
    }

    /// Cancels any pending retry.
    ///
    /// Call this when navigation succeeds or when the user manually retries.
    public func cancel() {
        retryTask?.cancel()
        retryTask = nil

        progressTask?.cancel()
        progressTask = nil

        hasFailure = false
        retryProgress = 0.0
        lastError = nil
    }

    /// Resets the handler to its initial state.
    ///
    /// Equivalent to calling `cancel()`.
    public func reset() {
        cancel()
    }

    /// Manually triggers a retry signal.
    ///
    /// Call this if you want to bypass the countdown and retry immediately.
    /// This will cancel any pending countdown and emit the retry signal.
    public func retryNow() {
        // Cancel the countdown
        retryTask?.cancel()
        retryTask = nil
        progressTask?.cancel()
        progressTask = nil

        // Reset state
        hasFailure = false
        retryProgress = 0.0

        // Emit retry signal
        shouldRetrySubject.send(true)
    }

    // MARK: - Private Methods

    /// Starts the retry countdown and progress updates.
    private func startRetryCountdown() {
        let delay = retryDelay
        let updateInterval = progressUpdateInterval
        let startTime = Date()

        // Start progress update task
        progressTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(1.0, elapsed / delay)

                self.retryProgress = progress

                if progress >= 1.0 {
                    break
                }

                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }
        }

        // Start retry task
        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Wait for the retry delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            // Check if cancelled
            if Task.isCancelled { return }

            // Reset state and emit retry signal
            self.hasFailure = false
            self.retryProgress = 0.0
            self.shouldRetrySubject.send(true)
        }
    }
}

// MARK: - Convenience Extensions

extension RetryHandler {
    /// Whether a retry is currently being scheduled.
    public var isCountingDown: Bool {
        hasFailure && retryTask != nil
    }

    /// The remaining time (in seconds) before retry, or nil if not counting down.
    public var remainingTime: TimeInterval? {
        guard isCountingDown else { return nil }
        return max(0, retryDelay * (1.0 - retryProgress))
    }

    /// A formatted string showing remaining time (e.g., "Retrying in 3s").
    public var remainingTimeString: String? {
        guard let remaining = remainingTime else { return nil }
        return "Retrying in \(Int(ceil(remaining)))s"
    }
}

// MARK: - Error Helpers

extension RetryHandler {
    /// Checks if an error should trigger a retry.
    ///
    /// - Parameter error: The error to check.
    /// - Returns: `true` if the error should trigger a retry, `false` if it should be ignored.
    public static func shouldRetry(for error: Error) -> Bool {
        let nsError = error as NSError
        // Ignore cancelled navigations
        if nsError.code == cancelledErrorCode {
            return false
        }
        return true
    }

    /// Extracts a user-friendly message from a navigation error.
    ///
    /// - Parameter error: The navigation error.
    /// - Returns: A localized description suitable for display.
    public static func userFriendlyMessage(for error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection"
        case NSURLErrorTimedOut:
            return "Connection timed out"
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost:
            return "Cannot connect to server"
        case NSURLErrorNetworkConnectionLost:
            return "Connection lost"
        default:
            return nsError.localizedDescription
        }
    }
}
