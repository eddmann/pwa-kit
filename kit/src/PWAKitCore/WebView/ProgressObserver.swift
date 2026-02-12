import Combine
import Foundation
import WebKit

// MARK: - ProgressObserver

/// Observes WKWebView's `estimatedProgress` property and publishes progress updates.
///
/// `ProgressObserver` uses KVO to monitor the loading progress of a WKWebView and
/// publishes updates through a Combine publisher. It also handles hiding the loading
/// view after completion with an optional delay.
///
/// ## How It Works
///
/// The observer monitors the `estimatedProgress` property (0.0 to 1.0) and publishes
/// updates to subscribers. When progress reaches 100%, it can optionally trigger
/// a hide callback after a configurable delay to allow the page to finish rendering.
///
/// ## Usage
///
/// ```swift
/// let observer = ProgressObserver()
///
/// // Subscribe to progress updates
/// observer.progressPublisher
///     .sink { progress in
///         loadingView.progress = progress
///     }
///     .store(in: &cancellables)
///
/// // Subscribe to loading completion
/// observer.isLoadingPublisher
///     .sink { isLoading in
///         loadingView.isVisible = isLoading
///     }
///     .store(in: &cancellables)
///
/// // Start observing
/// observer.observe(webView: myWebView)
///
/// // Later, when done:
/// observer.stopObserving()
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated as it interacts with UIKit/WebKit components.
@MainActor
public final class ProgressObserver {
    // MARK: - Publishers

    /// Publishes the current loading progress (0.0 to 1.0).
    public var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    /// Publishes whether the webview is currently loading.
    ///
    /// This becomes `false` after the progress reaches 100% and the hide delay has passed.
    public var isLoadingPublisher: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }

    // MARK: - Current Values

    /// The current loading progress (0.0 to 1.0).
    public private(set) var progress = 0.0 {
        didSet {
            progressSubject.send(progress)
        }
    }

    /// Whether the webview is currently loading.
    public private(set) var isLoading = true {
        didSet {
            isLoadingSubject.send(isLoading)
        }
    }

    // MARK: - Configuration

    /// The delay (in seconds) before hiding the loading view after reaching 100%.
    ///
    /// This delay allows the page content to finish rendering before the loading
    /// overlay is hidden. Default is 0.3 seconds.
    public var hideDelay: TimeInterval = 0.3

    /// The minimum progress threshold to consider loading started.
    ///
    /// Progress values below this threshold may be considered as "not yet started".
    /// Default is 0.1.
    public var startThreshold = 0.1

    // MARK: - Private Properties

    /// The KVO observation token for tracking progress changes.
    private var progressObservation: NSKeyValueObservation?

    /// The KVO observation token for tracking loading state.
    private var loadingObservation: NSKeyValueObservation?

    /// Weak reference to the observed WebView.
    private weak var observedWebView: WKWebView?

    /// Task for the delayed hide operation.
    private var hideTask: Task<Void, Never>?

    /// Subject for publishing progress updates.
    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)

    /// Subject for publishing loading state updates.
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(true)

    // MARK: - Initialization

    /// Creates a new progress observer.
    ///
    /// - Parameters:
    ///   - hideDelay: The delay before hiding after completion. Default is 0.3 seconds.
    public init(hideDelay: TimeInterval = 0.3) {
        self.hideDelay = hideDelay
    }

    deinit {
        MainActor.assumeIsolated {
            stopObserving()
        }
    }

    // MARK: - Public API

    /// Begins observing the WebView's loading progress.
    ///
    /// This method starts monitoring the `estimatedProgress` and `isLoading`
    /// properties of the WebView. Progress updates are published through
    /// `progressPublisher` and loading state through `isLoadingPublisher`.
    ///
    /// - Parameter webView: The WKWebView to observe.
    public func observe(webView: WKWebView) {
        // Stop any existing observation
        stopObserving()

        observedWebView = webView

        // Reset state
        progress = webView.estimatedProgress
        isLoading = webView.isLoading || webView.estimatedProgress < 1.0

        // Observe estimatedProgress
        progressObservation = webView.observe(
            \.estimatedProgress,
            options: [.new, .initial]
        ) { [weak self] webView, _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleProgressChange(webView.estimatedProgress)
            }
        }

        // Observe isLoading
        loadingObservation = webView.observe(
            \.isLoading,
            options: [.new]
        ) { [weak self] webView, _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleLoadingStateChange(webView.isLoading)
            }
        }
    }

    /// Stops observing the WebView's progress.
    ///
    /// Call this method when you no longer need progress updates or when
    /// the WebView is being deallocated.
    public func stopObserving() {
        hideTask?.cancel()
        hideTask = nil

        progressObservation?.invalidate()
        progressObservation = nil

        loadingObservation?.invalidate()
        loadingObservation = nil

        observedWebView = nil
    }

    /// Resets the observer to its initial loading state.
    ///
    /// Use this method to prepare for a new page load. This sets progress to 0
    /// and isLoading to true.
    public func reset() {
        hideTask?.cancel()
        hideTask = nil

        progress = 0.0
        isLoading = true
    }

    // MARK: - Private Helpers

    /// Handles changes to the estimated progress value.
    ///
    /// - Parameter newProgress: The new progress value (0.0 to 1.0).
    private func handleProgressChange(_ newProgress: Double) {
        progress = newProgress

        if newProgress >= 1.0 {
            // Progress is complete, schedule hide with delay
            scheduleHide()
        } else if newProgress > 0 {
            // Loading is in progress, cancel any pending hide
            hideTask?.cancel()
            hideTask = nil

            // Ensure we're showing loading state
            if !isLoading {
                isLoading = true
            }
        }
    }

    /// Handles changes to the isLoading property.
    ///
    /// - Parameter loading: Whether the webview is currently loading.
    private func handleLoadingStateChange(_ loading: Bool) {
        if loading {
            // A new load started
            hideTask?.cancel()
            hideTask = nil

            if !isLoading {
                isLoading = true
            }
        }
        // Note: We don't set isLoading = false here; we let the progress
        // reaching 100% + delay handle that for smoother transitions.
    }

    /// Schedules hiding the loading view after the configured delay.
    private func scheduleHide() {
        // Cancel any existing hide task
        hideTask?.cancel()

        hideTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Wait for the hide delay
            try? await Task.sleep(nanoseconds: UInt64(self.hideDelay * 1_000_000_000))

            // Check if cancelled
            if Task.isCancelled { return }

            // Only hide if progress is still at 100%
            if self.progress >= 1.0 {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Convenience Extensions

extension ProgressObserver {
    /// Whether the loading has completed (progress >= 1.0 and not actively loading).
    public var isComplete: Bool {
        progress >= 1.0 && !isLoading
    }

    /// A formatted progress percentage string (e.g., "45%").
    public var progressPercentageString: String {
        "\(Int(progress * 100))%"
    }

    /// Progress clamped to a valid range (0.0 to 1.0).
    public var clampedProgress: Double {
        min(1.0, max(0.0, progress))
    }
}
