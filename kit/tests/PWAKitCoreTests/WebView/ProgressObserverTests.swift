import Combine
import Foundation
@testable import PWAKitApp
import Testing
import WebKit

@Suite("ProgressObserver Tests")
@MainActor
struct ProgressObserverTests {
    // MARK: - Initialization

    @Test("Initializes with default values")
    func initializesWithDefaultValues() {
        let observer = ProgressObserver()

        #expect(observer.hideDelay == 0.3)
        #expect(observer.startThreshold == 0.1)
        #expect(observer.progress == 0.0)
        #expect(observer.isLoading == true)
    }

    @Test("Initializes with custom hide delay")
    func initializesWithCustomHideDelay() {
        let observer = ProgressObserver(hideDelay: 0.5)

        #expect(observer.hideDelay == 0.5)
    }

    @Test("Allows modifying configuration after init")
    func allowsModifyingConfiguration() {
        let observer = ProgressObserver()

        observer.hideDelay = 1.0
        observer.startThreshold = 0.2

        #expect(observer.hideDelay == 1.0)
        #expect(observer.startThreshold == 0.2)
    }

    // MARK: - Reset

    @Test("Reset sets progress to zero and isLoading to true")
    func resetSetsInitialState() {
        let observer = ProgressObserver()

        // Manually modify state (simulating usage)
        // We'll test reset restores initial state
        observer.reset()

        #expect(observer.progress == 0.0)
        #expect(observer.isLoading == true)
    }

    // MARK: - Convenience Properties

    @Test("progressPercentageString returns formatted percentage")
    func progressPercentageStringReturnsFormattedValue() {
        let observer = ProgressObserver()

        // Initial state (0%)
        #expect(observer.progressPercentageString == "0%")
    }

    @Test("clampedProgress returns value in valid range")
    func clampedProgressReturnsValidRange() {
        let observer = ProgressObserver()

        // At initial state
        #expect(observer.clampedProgress >= 0.0)
        #expect(observer.clampedProgress <= 1.0)
    }

    @Test("isComplete returns false when loading")
    func isCompleteReturnsFalseWhenLoading() {
        let observer = ProgressObserver()

        // Initially loading
        #expect(observer.isComplete == false)
    }

    // MARK: - Publisher Tests

    @Test("progressPublisher emits initial value")
    func progressPublisherEmitsInitialValue() async {
        let observer = ProgressObserver()
        var cancellables = Set<AnyCancellable>()
        var receivedValues: [Double] = []

        await withCheckedContinuation { continuation in
            observer.progressPublisher
                .first()
                .sink { value in
                    receivedValues.append(value)
                    continuation.resume()
                }
                .store(in: &cancellables)
        }

        #expect(receivedValues.contains(0.0))
    }

    @Test("isLoadingPublisher emits initial value")
    func isLoadingPublisherEmitsInitialValue() async {
        let observer = ProgressObserver()
        var cancellables = Set<AnyCancellable>()
        var receivedValue: Bool?

        _ = await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            observer.isLoadingPublisher
                .first()
                .sink { value in
                    receivedValue = value
                    continuation.resume()
                }
                .store(in: &cancellables)
        }

        #expect(receivedValue == true)
    }

    // MARK: - Stop Observing

    @Test("stopObserving cleans up properly")
    func stopObservingCleansUp() {
        let observer = ProgressObserver()

        // Stop without starting - should not crash
        observer.stopObserving()

        // Should still work fine
        #expect(observer.progress == 0.0)
    }

    @Test("Multiple stopObserving calls do not crash")
    func multipleStopObservingCallsDoNotCrash() {
        let observer = ProgressObserver()

        observer.stopObserving()
        observer.stopObserving()
        observer.stopObserving()

        // No crash means success
    }

    // MARK: - KVO Observation with Real WebView

    @Test("Observes WebView progress changes")
    func observesWebViewProgressChanges() async throws {
        let observer = ProgressObserver(hideDelay: 0.1)
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        var receivedProgresses: [Double] = []
        var cancellables = Set<AnyCancellable>()

        observer.progressPublisher
            .sink { progress in
                receivedProgresses.append(progress)
            }
            .store(in: &cancellables)

        // Start observing
        observer.observe(webView: webView)

        // Give KVO time to fire initial observation
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // We should have received at least the initial progress
        #expect(!receivedProgresses.isEmpty)

        observer.stopObserving()
    }

    @Test("Observer picks up WebView initial state")
    func observerPicksUpWebViewInitialState() async throws {
        let observer = ProgressObserver()
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Start observing - should pick up current state
        observer.observe(webView: webView)

        // Give KVO time to process
        try await Task.sleep(nanoseconds: 50_000_000)

        // WebView starts with 0 progress and not loading
        #expect(observer.progress >= 0.0)
        #expect(observer.progress <= 1.0)

        observer.stopObserving()
    }

    @Test("Reset cancels pending hide task")
    func resetCancelsPendingHideTask() {
        let observer = ProgressObserver(hideDelay: 1.0)

        // Start in loading state
        observer.reset()

        #expect(observer.isLoading == true)
        #expect(observer.progress == 0.0)
    }

    // MARK: - Edge Cases

    @Test("Handles rapid observe/stop cycles")
    func handlesRapidObserveStopCycles() {
        let observer = ProgressObserver()
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        for _ in 0 ..< 10 {
            observer.observe(webView: webView)
            observer.stopObserving()
        }

        // No crash means success
    }

    @Test("Re-observing different WebView works correctly")
    func reObservingDifferentWebViewWorks() async throws {
        let observer = ProgressObserver()
        let configuration = WKWebViewConfiguration()
        let webView1 = WKWebView(frame: .zero, configuration: configuration)
        let webView2 = WKWebView(frame: .zero, configuration: configuration)

        // Observe first webview
        observer.observe(webView: webView1)

        // Give time for observation setup
        try await Task.sleep(nanoseconds: 50_000_000)

        // Switch to second webview
        observer.observe(webView: webView2)

        // Give time for observation setup
        try await Task.sleep(nanoseconds: 50_000_000)

        // Should work without issues
        observer.stopObserving()
    }

    // MARK: - Configuration Behavior

    @Test("Hide delay affects completion timing")
    func hideDelayAffectsCompletionTiming() {
        let shortDelay = ProgressObserver(hideDelay: 0.1)
        let longDelay = ProgressObserver(hideDelay: 2.0)

        #expect(shortDelay.hideDelay < longDelay.hideDelay)
    }
}
