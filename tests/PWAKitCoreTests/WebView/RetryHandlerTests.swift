import Combine
import Foundation
import Testing

@testable import PWAKitApp

@Suite("RetryHandler Tests")
@MainActor
struct RetryHandlerTests {
    // MARK: - Initialization

    @Test("Initializes with default values")
    func initializesWithDefaultValues() {
        let handler = RetryHandler()

        #expect(handler.retryDelay == 6.0)
        #expect(handler.progressUpdateInterval == 0.1)
        #expect(handler.hasFailure == false)
        #expect(handler.retryProgress == 0.0)
        #expect(handler.lastError == nil)
    }

    @Test("Initializes with custom retry delay")
    func initializesWithCustomRetryDelay() {
        let handler = RetryHandler(retryDelay: 3.0)

        #expect(handler.retryDelay == 3.0)
    }

    @Test("Allows modifying configuration after init")
    func allowsModifyingConfiguration() {
        let handler = RetryHandler()

        handler.retryDelay = 10.0
        handler.progressUpdateInterval = 0.5

        #expect(handler.retryDelay == 10.0)
        #expect(handler.progressUpdateInterval == 0.5)
    }

    // MARK: - Cancelled Error Handling

    @Test("Ignores cancelled navigation errors")
    func ignoresCancelledNavigationErrors() async {
        let handler = RetryHandler(retryDelay: 0.1)

        // Create a cancelled error (code -999)
        let cancelledError = NSError(
            domain: NSURLErrorDomain,
            code: -999,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: cancelledError)

        // Should not trigger failure state
        #expect(handler.hasFailure == false)
        #expect(handler.lastError == nil)
    }

    @Test("shouldRetry returns false for cancelled errors")
    func shouldRetryReturnsFalseForCancelledErrors() {
        let cancelledError = NSError(
            domain: NSURLErrorDomain,
            code: -999,
            userInfo: nil
        )

        #expect(RetryHandler.shouldRetry(for: cancelledError) == false)
    }

    @Test("shouldRetry returns true for network errors")
    func shouldRetryReturnsTrueForNetworkErrors() {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        #expect(RetryHandler.shouldRetry(for: networkError) == true)
    }

    // MARK: - Navigation Failure Handling

    @Test("Handles navigation failure and sets state")
    func handlesNavigationFailureAndSetsState() {
        let handler = RetryHandler(retryDelay: 1.0)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)

        #expect(handler.hasFailure == true)
        #expect(handler.lastError != nil)
        #expect(handler.retryProgress == 0.0)
    }

    @Test("Stores the last error")
    func storesLastError() {
        let handler = RetryHandler(retryDelay: 1.0)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [NSLocalizedDescriptionKey: "Request timed out"]
        )

        handler.handleNavigationFailure(error: error)

        let nsError = handler.lastError as? NSError
        #expect(nsError?.code == NSURLErrorTimedOut)
    }

    // MARK: - Retry Countdown

    @Test("Emits retry signal after delay")
    func emitsRetrySignalAfterDelay() async throws {
        let handler = RetryHandler(retryDelay: 0.2)
        var cancellables = Set<AnyCancellable>()
        var receivedRetry = false

        handler.shouldRetryPublisher
            .sink { shouldRetry in
                if shouldRetry {
                    receivedRetry = true
                }
            }
            .store(in: &cancellables)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)

        // Wait for retry delay plus buffer
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        #expect(receivedRetry == true)
    }

    @Test("Updates retry progress during countdown")
    func updatesRetryProgressDuringCountdown() async throws {
        let handler = RetryHandler(retryDelay: 0.3)
        handler.progressUpdateInterval = 0.05 // Faster updates for test

        var cancellables = Set<AnyCancellable>()
        var receivedProgresses: [Double] = []

        handler.retryProgressPublisher
            .sink { progress in
                receivedProgresses.append(progress)
            }
            .store(in: &cancellables)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)

        // Wait for countdown to complete
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms

        // Should have received multiple progress updates
        #expect(receivedProgresses.count > 1)

        // Progress should have increased
        let maxProgress = receivedProgresses.max() ?? 0
        #expect(maxProgress >= 0.9)
    }

    @Test("Publishes hasFailure changes")
    func publishesHasFailureChanges() async throws {
        let handler = RetryHandler(retryDelay: 0.1)
        var cancellables = Set<AnyCancellable>()
        var receivedStates: [Bool] = []

        handler.hasFailurePublisher
            .sink { hasFailure in
                receivedStates.append(hasFailure)
            }
            .store(in: &cancellables)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        // Should receive initial false
        #expect(receivedStates.contains(false))

        handler.handleNavigationFailure(error: error)

        // Should receive true after failure
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        #expect(receivedStates.contains(true))

        // Wait for retry to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Should receive false after retry
        #expect(receivedStates.last == false)
    }

    // MARK: - Cancel

    @Test("Cancel resets state")
    func cancelResetsState() {
        let handler = RetryHandler(retryDelay: 1.0)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)
        #expect(handler.hasFailure == true)

        handler.cancel()

        #expect(handler.hasFailure == false)
        #expect(handler.retryProgress == 0.0)
        #expect(handler.lastError == nil)
    }

    @Test("Cancel stops pending retry")
    func cancelStopsPendingRetry() async throws {
        let handler = RetryHandler(retryDelay: 0.3)
        var cancellables = Set<AnyCancellable>()
        var receivedRetry = false

        handler.shouldRetryPublisher
            .sink { shouldRetry in
                if shouldRetry {
                    receivedRetry = true
                }
            }
            .store(in: &cancellables)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)

        // Cancel before delay completes
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        handler.cancel()

        // Wait past original delay
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms

        // Should not have received retry signal
        #expect(receivedRetry == false)
    }

    @Test("Reset is equivalent to cancel")
    func resetIsEquivalentToCancel() {
        let handler = RetryHandler(retryDelay: 1.0)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)
        handler.reset()

        #expect(handler.hasFailure == false)
        #expect(handler.retryProgress == 0.0)
        #expect(handler.lastError == nil)
    }

    // MARK: - Retry Now

    @Test("retryNow emits signal immediately")
    func retryNowEmitsSignalImmediately() async throws {
        let handler = RetryHandler(retryDelay: 10.0) // Long delay
        var cancellables = Set<AnyCancellable>()
        var receivedRetry = false

        handler.shouldRetryPublisher
            .sink { shouldRetry in
                if shouldRetry {
                    receivedRetry = true
                }
            }
            .store(in: &cancellables)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)

        // Immediately trigger retry
        handler.retryNow()

        // Give publisher time to emit
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        #expect(receivedRetry == true)
        #expect(handler.hasFailure == false)
    }

    // MARK: - Convenience Properties

    @Test("isCountingDown returns true during countdown")
    func isCountingDownReturnsTrueDuringCountdown() {
        let handler = RetryHandler(retryDelay: 1.0)

        #expect(handler.isCountingDown == false)

        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        handler.handleNavigationFailure(error: error)

        #expect(handler.isCountingDown == true)

        handler.cancel()

        #expect(handler.isCountingDown == false)
    }

    @Test("remainingTime returns nil when not counting down")
    func remainingTimeReturnsNilWhenNotCountingDown() {
        let handler = RetryHandler(retryDelay: 6.0)

        #expect(handler.remainingTime == nil)
    }

    @Test("remainingTimeString returns nil when not counting down")
    func remainingTimeStringReturnsNilWhenNotCountingDown() {
        let handler = RetryHandler(retryDelay: 6.0)

        #expect(handler.remainingTimeString == nil)
    }

    // MARK: - User-Friendly Messages

    @Test("userFriendlyMessage returns appropriate message for no internet")
    func userFriendlyMessageReturnsAppropriateMessageForNoInternet() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        let message = RetryHandler.userFriendlyMessage(for: error)
        #expect(message == "No internet connection")
    }

    @Test("userFriendlyMessage returns appropriate message for timeout")
    func userFriendlyMessageReturnsAppropriateMessageForTimeout() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        let message = RetryHandler.userFriendlyMessage(for: error)
        #expect(message == "Connection timed out")
    }

    @Test("userFriendlyMessage returns appropriate message for cannot find host")
    func userFriendlyMessageReturnsAppropriateMessageForCannotFindHost() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotFindHost,
            userInfo: nil
        )

        let message = RetryHandler.userFriendlyMessage(for: error)
        #expect(message == "Cannot connect to server")
    }

    @Test("userFriendlyMessage returns appropriate message for connection lost")
    func userFriendlyMessageReturnsAppropriateMessageForConnectionLost() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        let message = RetryHandler.userFriendlyMessage(for: error)
        #expect(message == "Connection lost")
    }

    @Test("userFriendlyMessage returns localized description for unknown errors")
    func userFriendlyMessageReturnsLocalizedDescriptionForUnknownErrors() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: -12345,
            userInfo: [NSLocalizedDescriptionKey: "Some unknown error"]
        )

        let message = RetryHandler.userFriendlyMessage(for: error)
        #expect(message == "Some unknown error")
    }

    // MARK: - Multiple Failures

    @Test("New failure cancels existing countdown", .disabled("Flaky timing-sensitive test"))
    func newFailureCancelsExistingCountdown() async throws {
        let handler = RetryHandler(retryDelay: 0.3)
        var cancellables = Set<AnyCancellable>()
        var retryCount = 0

        handler.shouldRetryPublisher
            .sink { shouldRetry in
                if shouldRetry {
                    retryCount += 1
                }
            }
            .store(in: &cancellables)

        let error1 = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        let error2 = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        // Start first countdown
        handler.handleNavigationFailure(error: error1)

        // Wait a bit then start second countdown
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        handler.handleNavigationFailure(error: error2)

        // Wait for second countdown to complete
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms

        // Should only get one retry signal (from second countdown)
        #expect(retryCount == 1)

        // Last error should be the second one
        let nsError = handler.lastError as? NSError
        #expect(nsError?.code == NSURLErrorTimedOut)
    }

    // MARK: - Edge Cases

    @Test("Multiple cancel calls do not crash")
    func multipleCancelCallsDoNotCrash() {
        let handler = RetryHandler()

        handler.cancel()
        handler.cancel()
        handler.cancel()

        // No crash means success
    }

    @Test("retryNow without failure does not crash")
    func retryNowWithoutFailureDoesNotCrash() async throws {
        let handler = RetryHandler()
        var cancellables = Set<AnyCancellable>()
        var receivedRetry = false

        handler.shouldRetryPublisher
            .sink { shouldRetry in
                if shouldRetry {
                    receivedRetry = true
                }
            }
            .store(in: &cancellables)

        // Call retryNow without any failure
        handler.retryNow()

        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Should still emit signal
        #expect(receivedRetry == true)
    }
}
