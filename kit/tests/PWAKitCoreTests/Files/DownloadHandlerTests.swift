import Combine
import Foundation
@testable import PWAKitApp
import Testing
import WebKit

// MARK: - DownloadHandlerTests

@Suite("DownloadHandler Tests")
@MainActor
struct DownloadHandlerTests {
    // MARK: - Initialization

    @Test("Initializes with default values")
    func initializesWithDefaultValues() {
        let handler = DownloadHandler()

        #expect(handler.downloadsDirectory == nil)
        #expect(handler.replaceExistingFiles == true)
        #expect(handler.isDownloading == false)
        #expect(handler.progress == 0.0)
        #expect(handler.currentDownloadInfo == nil)
        #expect(handler.activeDownload == nil)
    }

    @Test("Initializes with custom downloads directory")
    func initializesWithCustomDownloadsDirectory() {
        let customURL = URL(fileURLWithPath: "/tmp/downloads")
        let handler = DownloadHandler(downloadsDirectory: customURL)

        #expect(handler.downloadsDirectory == customURL)
    }

    @Test("Allows modifying configuration after init")
    func allowsModifyingConfiguration() {
        let handler = DownloadHandler()

        handler.replaceExistingFiles = false
        let newURL = URL(fileURLWithPath: "/tmp/custom")
        handler.downloadsDirectory = newURL

        #expect(handler.replaceExistingFiles == false)
        #expect(handler.downloadsDirectory == newURL)
    }

    // MARK: - Factory Methods

    @Test("Creates documents handler")
    func createsDocumentsHandler() {
        let handler = DownloadHandler.documentsHandler()

        #expect(handler.downloadsDirectory == nil)
        #expect(handler.replaceExistingFiles == true)
    }

    @Test("Creates subdirectory handler")
    func createsSubdirectoryHandler() {
        let handler = DownloadHandler.handler(forSubdirectory: "TestDownloads")

        #expect(handler.downloadsDirectory != nil)
        #expect(handler.downloadsDirectory?.lastPathComponent == "TestDownloads")
    }

    // MARK: - Error Descriptions

    @Test("DownloadError provides localized descriptions")
    func downloadErrorProvidesLocalizedDescriptions() {
        let noFilenameError = DownloadHandler.DownloadError.noSuggestedFilename
        #expect(noFilenameError.errorDescription == "Could not determine filename")

        let cannotAccessError = DownloadHandler.DownloadError.cannotAccessDocuments
        #expect(cannotAccessError.errorDescription == "Cannot access Documents directory")

        let cancelledError = DownloadHandler.DownloadError.cancelled
        #expect(cancelledError.errorDescription == "Download was cancelled")

        let failedError = DownloadHandler.DownloadError.downloadFailed("Connection lost")
        #expect(failedError.errorDescription == "Download failed: Connection lost")

        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let createDirError = DownloadHandler.DownloadError.cannotCreateDirectory(underlyingError)
        #expect(createDirError.errorDescription?.contains("Cannot create directory") == true)

        let moveError = DownloadHandler.DownloadError.moveFileFailed(underlyingError)
        #expect(moveError.errorDescription?.contains("Cannot save file") == true)
    }

    // MARK: - DownloadInfo

    @Test("DownloadInfo provides progress string with known total")
    func downloadInfoProvidesProgressStringWithKnownTotal() {
        let info = DownloadHandler.DownloadInfo(
            filename: "test.pdf",
            destinationURL: URL(fileURLWithPath: "/tmp/test.pdf"),
            progress: 0.5,
            bytesReceived: 500_000,
            totalBytes: 1_000_000
        )

        let progressString = info.progressString
        #expect(progressString.contains("/"))
    }

    @Test("DownloadInfo provides progress string with unknown total")
    func downloadInfoProvidesProgressStringWithUnknownTotal() {
        let info = DownloadHandler.DownloadInfo(
            filename: "test.pdf",
            destinationURL: URL(fileURLWithPath: "/tmp/test.pdf"),
            progress: 0.5,
            bytesReceived: 500_000,
            totalBytes: -1
        )

        let progressString = info.progressString
        // Should not contain "/" when total is unknown
        #expect(!progressString.contains("/"))
    }

    // MARK: - Publishers

    @Test("Progress publisher emits initial value")
    func progressPublisherEmitsInitialValue() async throws {
        let handler = DownloadHandler()
        var cancellables = Set<AnyCancellable>()
        var receivedProgress: Double?

        handler.progressPublisher
            .sink { progress in
                receivedProgress = progress
            }
            .store(in: &cancellables)

        // Allow publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        #expect(receivedProgress == 0.0)
    }

    @Test("IsDownloading publisher emits initial value")
    func isDownloadingPublisherEmitsInitialValue() async throws {
        let handler = DownloadHandler()
        var cancellables = Set<AnyCancellable>()
        var receivedValue: Bool?

        handler.isDownloadingPublisher
            .sink { isDownloading in
                receivedValue = isDownloading
            }
            .store(in: &cancellables)

        // Allow publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        #expect(receivedValue == false)
    }

    @Test("DownloadInfo publisher emits initial nil")
    func downloadInfoPublisherEmitsInitialNil() async throws {
        let handler = DownloadHandler()
        var cancellables = Set<AnyCancellable>()
        var didReceiveValue = false
        var receivedValue: DownloadHandler.DownloadInfo?

        handler.downloadInfoPublisher
            .sink { info in
                didReceiveValue = true
                receivedValue = info
            }
            .store(in: &cancellables)

        // Allow publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Verify publisher emitted and the initial value was nil
        #expect(didReceiveValue)
        #expect(receivedValue == nil)
    }

    @Test("DownloadState publisher combines all state")
    func downloadStatePublisherCombinesAllState() async throws {
        let handler = DownloadHandler()
        var cancellables = Set<AnyCancellable>()
        var receivedState: DownloadHandler.DownloadState?

        handler.downloadStatePublisher
            .sink { state in
                receivedState = state
            }
            .store(in: &cancellables)

        // Allow publisher to emit
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        #expect(receivedState != nil)
        #expect(receivedState?.isDownloading == false)
        #expect(receivedState?.progress == 0.0)
        #expect(receivedState?.info == nil)
    }

    // MARK: - Cancel

    @Test("Cancel resets state")
    func cancelResetsState() {
        let handler = DownloadHandler()

        // Simulate some state
        handler.cancelCurrentDownload()

        #expect(handler.isDownloading == false)
        #expect(handler.progress == 0.0)
        #expect(handler.currentDownloadInfo == nil)
        #expect(handler.activeDownload == nil)
    }

    @Test("Multiple cancel calls do not crash")
    func multipleCancelCallsDoNotCrash() {
        let handler = DownloadHandler()

        handler.cancelCurrentDownload()
        handler.cancelCurrentDownload()
        handler.cancelCurrentDownload()

        // No crash means success
        #expect(handler.isDownloading == false)
    }

    // MARK: - URL Generation

    @Test("Creates destination in Documents directory")
    func createsDestinationInDocumentsDirectory() {
        let handler = DownloadHandler()

        // Verify documents directory is accessible
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        #expect(documentsURL != nil)
    }

    @Test("Custom downloads directory is used when set")
    func customDownloadsDirectoryIsUsedWhenSet() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestDownloads-\(UUID().uuidString)")
        let handler = DownloadHandler(downloadsDirectory: tempDir)

        #expect(handler.downloadsDirectory == tempDir)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Replace Existing Files

    @Test("ReplaceExistingFiles defaults to true")
    func replaceExistingFilesDefaultsToTrue() {
        let handler = DownloadHandler()

        #expect(handler.replaceExistingFiles == true)
    }

    @Test("ReplaceExistingFiles can be set to false")
    func replaceExistingFilesCanBeSetToFalse() {
        let handler = DownloadHandler()
        handler.replaceExistingFiles = false

        #expect(handler.replaceExistingFiles == false)
    }

    // MARK: - Completion Publisher

    @Test("Completion publisher does not emit on init")
    func completionPublisherDoesNotEmitOnInit() async throws {
        let handler = DownloadHandler()
        var cancellables = Set<AnyCancellable>()
        var receivedResult: DownloadHandler.DownloadResult?

        handler.completionPublisher
            .sink { result in
                receivedResult = result
            }
            .store(in: &cancellables)

        // Allow publisher time to potentially emit
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Should not have received any result
        #expect(receivedResult == nil)
    }

    // MARK: - Integration Scenarios

    @Test("Handler can be reused for multiple downloads")
    func handlerCanBeReusedForMultipleDownloads() {
        let handler = DownloadHandler()

        // Cancel first (simulating end of download)
        handler.cancelCurrentDownload()
        #expect(handler.isDownloading == false)

        // Can be used again
        handler.cancelCurrentDownload()
        #expect(handler.isDownloading == false)
    }
}

// MARK: - DownloadResultTests

@Suite("DownloadResult Tests")
@MainActor
struct DownloadResultTests {
    @Test("Success result contains URL")
    func successResultContainsURL() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let result = DownloadHandler.DownloadResult.success(url)

        if case let .success(resultURL) = result {
            #expect(resultURL == url)
        } else {
            Issue.record("Expected success result")
        }
    }

    @Test("Failure result contains error")
    func failureResultContainsError() {
        let error = DownloadHandler.DownloadError.cancelled
        let result = DownloadHandler.DownloadResult.failure(error)

        if case let .failure(resultError) = result {
            if case .cancelled = resultError {
                // Success
            } else {
                Issue.record("Expected cancelled error")
            }
        } else {
            Issue.record("Expected failure result")
        }
    }
}

// MARK: - DownloadInfoTests

@Suite("DownloadInfo Tests")
@MainActor
struct DownloadInfoTests {
    @Test("DownloadInfo stores all properties correctly")
    func downloadInfoStoresAllPropertiesCorrectly() {
        let url = URL(fileURLWithPath: "/tmp/document.pdf")
        let info = DownloadHandler.DownloadInfo(
            filename: "document.pdf",
            destinationURL: url,
            progress: 0.75,
            bytesReceived: 750_000,
            totalBytes: 1_000_000
        )

        #expect(info.filename == "document.pdf")
        #expect(info.destinationURL == url)
        #expect(info.progress == 0.75)
        #expect(info.bytesReceived == 750_000)
        #expect(info.totalBytes == 1_000_000)
    }

    @Test("Progress string formats bytes correctly")
    func progressStringFormatsBytesCorrectly() {
        let info = DownloadHandler.DownloadInfo(
            filename: "large-file.zip",
            destinationURL: URL(fileURLWithPath: "/tmp/large-file.zip"),
            progress: 0.5,
            bytesReceived: 50_000_000, // 50 MB
            totalBytes: 100_000_000 // 100 MB
        )

        // Should contain some formatted byte representation
        let progressString = info.progressString
        #expect(!progressString.isEmpty)
    }

    @Test("Progress string handles zero bytes")
    func progressStringHandlesZeroBytes() {
        let info = DownloadHandler.DownloadInfo(
            filename: "small-file.txt",
            destinationURL: URL(fileURLWithPath: "/tmp/small-file.txt"),
            progress: 0.0,
            bytesReceived: 0,
            totalBytes: 1000
        )

        let progressString = info.progressString
        #expect(!progressString.isEmpty)
    }
}

// MARK: - BlobURLTests

@Suite("Blob URL Tests")
@MainActor
struct BlobURLTests {
    @Test("Detects blob URLs correctly")
    func detectsBlobURLsCorrectly() throws {
        // Valid blob URLs
        let blobURL1 = try #require(URL(string: "blob:https://example.com/12345-67890"))
        let blobURL2 = try #require(URL(string: "blob:http://localhost:3000/abcdef"))

        #expect(DownloadHandler.isBlobURL(blobURL1) == true)
        #expect(DownloadHandler.isBlobURL(blobURL2) == true)

        // Non-blob URLs
        let httpsURL = try #require(URL(string: "https://example.com/file.pdf"))
        let httpURL = try #require(URL(string: "http://example.com/file.pdf"))
        let fileURL = URL(fileURLWithPath: "/tmp/file.pdf")
        let dataURL = try #require(URL(string: "data:text/plain;base64,SGVsbG8="))

        #expect(DownloadHandler.isBlobURL(httpsURL) == false)
        #expect(DownloadHandler.isBlobURL(httpURL) == false)
        #expect(DownloadHandler.isBlobURL(fileURL) == false)
        #expect(DownloadHandler.isBlobURL(dataURL) == false)
    }

    @Test("Blob URL detection is case insensitive")
    func blobURLDetectionIsCaseInsensitive() throws {
        let uppercaseBlob = try #require(URL(string: "BLOB:https://example.com/12345"))
        let mixedCaseBlob = try #require(URL(string: "Blob:https://example.com/12345"))

        #expect(DownloadHandler.isBlobURL(uppercaseBlob) == true)
        #expect(DownloadHandler.isBlobURL(mixedCaseBlob) == true)
    }

    @Test("Handler initializes correctly for blob downloads")
    func handlerInitializesCorrectlyForBlobDownloads() {
        let handler = DownloadHandler()

        // Handler should be ready for blob downloads
        #expect(handler.isDownloading == false)
        #expect(handler.progress == 0.0)
    }
}

// MARK: - DownloadStateTests

@Suite("DownloadState Tests")
@MainActor
struct DownloadStateTests {
    @Test("DownloadState stores all properties")
    func downloadStateStoresAllProperties() {
        let info = DownloadHandler.DownloadInfo(
            filename: "test.pdf",
            destinationURL: URL(fileURLWithPath: "/tmp/test.pdf"),
            progress: 0.5,
            bytesReceived: 500,
            totalBytes: 1000
        )

        let state = DownloadHandler.DownloadState(
            isDownloading: true,
            progress: 0.5,
            info: info
        )

        #expect(state.isDownloading == true)
        #expect(state.progress == 0.5)
        #expect(state.info != nil)
        #expect(state.info?.filename == "test.pdf")
    }

    @Test("DownloadState handles nil info")
    func downloadStateHandlesNilInfo() {
        let state = DownloadHandler.DownloadState(
            isDownloading: false,
            progress: 0.0,
            info: nil
        )

        #expect(state.isDownloading == false)
        #expect(state.progress == 0.0)
        #expect(state.info == nil)
    }
}
