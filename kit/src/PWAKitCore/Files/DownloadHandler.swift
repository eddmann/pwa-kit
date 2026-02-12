import Combine
import Foundation
import WebKit

// MARK: - DownloadHandler

/// Handles file downloads from WKWebView using WKDownloadDelegate.
///
/// `DownloadHandler` manages the complete download lifecycle:
/// 1. Receives download request from navigation or response
/// 2. Determines destination in Documents directory
/// 3. Handles existing file replacement
/// 4. Tracks download progress
/// 5. Reports completion or failure
///
/// ## How It Works
///
/// When a navigation action becomes a download:
/// ```swift
/// func webView(_ webView: WKWebView,
///              navigationAction: WKNavigationAction,
///              didBecome download: WKDownload) {
///     downloadHandler.handleDownload(download)
/// }
/// ```
///
/// Monitor progress and completion via publishers:
/// ```swift
/// downloadHandler.progressPublisher
///     .sink { progress in
///         updateProgressBar(progress)
///     }
///
/// downloadHandler.completionPublisher
///     .sink { result in
///         switch result {
///         case .success(let url):
///             showPreview(for: url)
///         case .failure(let error):
///             showError(error)
///         }
///     }
/// ```
///
/// ## Thread Safety
///
/// This class is `@MainActor` isolated as it interacts with WKWebView
/// and UI components.
@MainActor
public final class DownloadHandler: NSObject {
    // MARK: - Types

    /// The result of a completed download.
    public enum DownloadResult: Sendable {
        /// Download succeeded with the file URL.
        case success(URL)
        /// Download failed with an error.
        case failure(DownloadError)
    }

    /// Errors that can occur during download.
    public enum DownloadError: Error, LocalizedError, Sendable {
        /// Failed to determine the suggested filename.
        case noSuggestedFilename
        /// Failed to access the Documents directory.
        case cannotAccessDocuments
        /// Failed to create the destination directory.
        case cannotCreateDirectory(Error)
        /// Download was cancelled.
        case cancelled
        /// Download failed with an underlying error.
        case downloadFailed(String)
        /// Failed to move the downloaded file.
        case moveFileFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .noSuggestedFilename:
                "Could not determine filename"
            case .cannotAccessDocuments:
                "Cannot access Documents directory"
            case let .cannotCreateDirectory(error):
                "Cannot create directory: \(error.localizedDescription)"
            case .cancelled:
                "Download was cancelled"
            case let .downloadFailed(message):
                "Download failed: \(message)"
            case let .moveFileFailed(error):
                "Cannot save file: \(error.localizedDescription)"
            }
        }
    }

    /// Information about an active download.
    public struct DownloadInfo: Sendable {
        /// The suggested filename for the download.
        public let filename: String
        /// The destination URL where the file will be saved.
        public let destinationURL: URL
        /// The current progress (0.0 to 1.0).
        public var progress: Double
        /// The number of bytes received.
        public var bytesReceived: Int64
        /// The total expected bytes (-1 if unknown).
        public var totalBytes: Int64

        /// A formatted string showing download progress.
        public var progressString: String {
            if totalBytes > 0 {
                let received = ByteCountFormatter.string(fromByteCount: bytesReceived, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                return "\(received) / \(total)"
            } else {
                let received = ByteCountFormatter.string(fromByteCount: bytesReceived, countStyle: .file)
                return received
            }
        }
    }

    // MARK: - Publishers

    /// Publishes download progress updates (0.0 to 1.0).
    public var progressPublisher: AnyPublisher<Double, Never> {
        progressSubject.eraseToAnyPublisher()
    }

    /// Publishes download completion results.
    public var completionPublisher: AnyPublisher<DownloadResult, Never> {
        completionSubject.eraseToAnyPublisher()
    }

    /// Publishes download info updates.
    public var downloadInfoPublisher: AnyPublisher<DownloadInfo?, Never> {
        downloadInfoSubject.eraseToAnyPublisher()
    }

    /// Publishes whether a download is currently in progress.
    public var isDownloadingPublisher: AnyPublisher<Bool, Never> {
        isDownloadingSubject.eraseToAnyPublisher()
    }

    // MARK: - Current State

    /// The current download progress (0.0 to 1.0).
    public private(set) var progress = 0.0 {
        didSet {
            progressSubject.send(progress)
        }
    }

    /// Information about the current download, if any.
    public private(set) var currentDownloadInfo: DownloadInfo? {
        didSet {
            downloadInfoSubject.send(currentDownloadInfo)
        }
    }

    /// Whether a download is currently in progress.
    public private(set) var isDownloading = false {
        didSet {
            isDownloadingSubject.send(isDownloading)
        }
    }

    /// The active download, if any.
    public private(set) weak var activeDownload: WKDownload?

    // MARK: - Configuration

    /// The directory where downloads are saved.
    ///
    /// Defaults to the user's Documents directory.
    public var downloadsDirectory: URL?

    /// Whether to replace existing files with the same name.
    ///
    /// Default is `true`. If `false`, a unique filename is generated.
    public var replaceExistingFiles = true

    // MARK: - Private Properties

    private let progressSubject = CurrentValueSubject<Double, Never>(0.0)
    private let completionSubject = PassthroughSubject<DownloadResult, Never>()
    private let downloadInfoSubject = CurrentValueSubject<DownloadInfo?, Never>(nil)
    private let isDownloadingSubject = CurrentValueSubject<Bool, Never>(false)

    /// The destination URL for the current download.
    private var pendingDestinationURL: URL?

    // MARK: - Initialization

    /// Creates a new download handler.
    ///
    /// - Parameter downloadsDirectory: Optional custom downloads directory.
    ///   If nil, uses the user's Documents directory.
    public init(downloadsDirectory: URL? = nil) {
        self.downloadsDirectory = downloadsDirectory
        super.init()
    }

    // MARK: - Public API

    /// Handles a download that originated from a navigation action.
    ///
    /// Call this from `webView(_:navigationAction:didBecome:)`.
    ///
    /// - Parameter download: The WKDownload to handle.
    public func handleDownload(_ download: WKDownload) {
        // Cancel any existing download
        cancelCurrentDownload()

        // Set up the new download
        activeDownload = download
        download.delegate = self
        isDownloading = true
        progress = 0.0

        // Download info will be set when we receive the suggested filename
    }

    /// Handles a download that originated from a navigation response.
    ///
    /// Call this from `webView(_:navigationResponse:didBecome:)`.
    ///
    /// - Parameter download: The WKDownload to handle.
    public func handleResponseDownload(_ download: WKDownload) {
        // Same handling as navigation action downloads
        handleDownload(download)
    }

    /// Cancels the current download, if any.
    public func cancelCurrentDownload() {
        activeDownload?.cancel()
        resetState()
    }

    // MARK: - Private Methods

    /// Resets the handler state.
    private func resetState() {
        activeDownload = nil
        isDownloading = false
        progress = 0.0
        currentDownloadInfo = nil
        pendingDestinationURL = nil
    }

    /// Gets the downloads directory, creating it if necessary.
    ///
    /// - Returns: The downloads directory URL.
    /// - Throws: `DownloadError` if the directory cannot be accessed or created.
    private func getDownloadsDirectory() throws -> URL {
        if let customDirectory = downloadsDirectory {
            // Ensure custom directory exists
            if !FileManager.default.fileExists(atPath: customDirectory.path) {
                do {
                    try FileManager.default.createDirectory(
                        at: customDirectory,
                        withIntermediateDirectories: true
                    )
                } catch {
                    throw DownloadError.cannotCreateDirectory(error)
                }
            }
            return customDirectory
        }

        // Use Documents directory
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw DownloadError.cannotAccessDocuments
        }

        return documentsURL
    }

    /// Determines the destination URL for a download.
    ///
    /// - Parameter suggestedFilename: The suggested filename from the server.
    /// - Returns: The destination URL.
    /// - Throws: `DownloadError` if the destination cannot be determined.
    private func destinationURL(for suggestedFilename: String) throws -> URL {
        let directory = try getDownloadsDirectory()
        var destinationURL = directory.appendingPathComponent(suggestedFilename)

        if !replaceExistingFiles {
            // Generate unique filename if file exists
            destinationURL = uniqueURL(for: destinationURL)
        }

        return destinationURL
    }

    /// Generates a unique URL by appending a number to the filename.
    ///
    /// - Parameter url: The original URL.
    /// - Returns: A unique URL that doesn't conflict with existing files.
    private func uniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: url.path) {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 1
        var newURL: URL

        repeat {
            let newFilename = ext.isEmpty
                ? "\(filename) (\(counter))"
                : "\(filename) (\(counter)).\(ext)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        } while fileManager.fileExists(atPath: newURL.path)

        return newURL
    }

    /// Removes any existing file at the destination URL.
    ///
    /// - Parameter url: The URL of the file to remove.
    private func removeExistingFile(at url: URL) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Reports a download completion.
    ///
    /// - Parameter result: The download result.
    private func reportCompletion(_ result: DownloadResult) {
        completionSubject.send(result)
        resetState()
    }
}

// MARK: WKDownloadDelegate

extension DownloadHandler: WKDownloadDelegate {
    /// Called when the download determines a suggested filename.
    ///
    /// This method determines the destination URL and starts the download.
    public nonisolated func download(
        _: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        await MainActor.run {
            guard !suggestedFilename.isEmpty else {
                reportCompletion(.failure(.noSuggestedFilename))
                return nil
            }

            do {
                let destination = try destinationURL(for: suggestedFilename)
                pendingDestinationURL = destination

                // Remove existing file if replacing
                if replaceExistingFiles {
                    removeExistingFile(at: destination)
                }

                // Update download info
                currentDownloadInfo = DownloadInfo(
                    filename: suggestedFilename,
                    destinationURL: destination,
                    progress: 0.0,
                    bytesReceived: 0,
                    totalBytes: response.expectedContentLength
                )

                return destination
            } catch let error as DownloadError {
                reportCompletion(.failure(error))
                return nil
            } catch {
                reportCompletion(.failure(.downloadFailed(error.localizedDescription)))
                return nil
            }
        }
    }

    /// Called periodically as the download progresses.
    public nonisolated func download(
        _: WKDownload,
        didReceive _: Data,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            let newProgress: Double = if totalBytesExpectedToWrite > 0 {
                Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            } else {
                // Unknown total size, estimate based on received data
                min(0.99, Double(totalBytesWritten) / 10_000_000.0)
            }

            progress = newProgress

            // Update download info
            if var info = currentDownloadInfo {
                info.progress = newProgress
                info.bytesReceived = totalBytesWritten
                info.totalBytes = totalBytesExpectedToWrite
                currentDownloadInfo = info
            }
        }
    }

    /// Called when the download completes successfully.
    public nonisolated func downloadDidFinish(_: WKDownload) {
        Task { @MainActor in
            progress = 1.0

            if let destination = pendingDestinationURL {
                reportCompletion(.success(destination))
            } else {
                reportCompletion(.failure(.downloadFailed("Unknown destination")))
            }
        }
    }

    /// Called when the download fails.
    public nonisolated func download(
        _: WKDownload,
        didFailWithError error: Error,
        resumeData _: Data?
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                reportCompletion(.failure(.cancelled))
            } else {
                reportCompletion(.failure(.downloadFailed(error.localizedDescription)))
            }
        }
    }
}

// MARK: - Blob URL Handling

extension DownloadHandler {
    /// Checks if a URL is a blob URL.
    ///
    /// Blob URLs have the scheme `blob:` and are created by JavaScript's
    /// `URL.createObjectURL()` method.
    ///
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if the URL is a blob URL.
    public static func isBlobURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "blob"
    }

    /// Handles a blob URL download by extracting data via JavaScript.
    ///
    /// Blob URLs cannot be downloaded directly by WKWebView's download API.
    /// Instead, we inject JavaScript to fetch the blob, convert it to base64,
    /// and pass it back to Swift for saving.
    ///
    /// - Parameters:
    ///   - url: The blob URL to download.
    ///   - webView: The WKWebView to execute JavaScript in.
    ///   - suggestedFilename: Optional filename. If nil, extracts from URL or uses default.
    public func handleBlobDownload(
        _ url: URL,
        webView: WKWebView,
        suggestedFilename: String? = nil
    ) {
        // Cancel any existing download
        cancelCurrentDownload()

        isDownloading = true
        progress = 0.0

        // Determine filename
        let filename = suggestedFilename ?? extractFilename(from: url) ?? "download"

        // JavaScript to fetch blob and convert to base64
        let javascript = Self.blobDownloadJavaScript(for: url.absoluteString)

        webView.evaluateJavaScript(javascript) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.reportCompletion(.failure(.downloadFailed(error.localizedDescription)))
                return
            }

            guard let resultDict = result as? [String: Any],
                  let base64Data = resultDict["data"] as? String,
                  let mimeType = resultDict["type"] as? String else
            {
                self.reportCompletion(.failure(.downloadFailed("Failed to extract blob data")))
                return
            }

            // Add extension based on MIME type if not present
            let finalFilename = self.ensureFileExtension(filename, mimeType: mimeType)

            // Decode base64 and save
            self.saveBlobData(base64Data, filename: finalFilename)
        }
    }

    /// Generates JavaScript code to fetch a blob URL and convert to base64.
    ///
    /// - Parameter blobURLString: The blob URL string.
    /// - Returns: JavaScript code string.
    private static func blobDownloadJavaScript(for blobURLString: String) -> String {
        """
        (async function() {
            try {
                const response = await fetch('\(blobURLString)');
                const blob = await response.blob();
                return new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onloadend = () => {
                        const base64 = reader.result.split(',')[1];
                        resolve({ data: base64, type: blob.type, size: blob.size });
                    };
                    reader.onerror = reject;
                    reader.readAsDataURL(blob);
                });
            } catch (error) {
                throw new Error('Failed to fetch blob: ' + error.message);
            }
        })();
        """
    }

    /// Extracts a filename from a blob URL.
    ///
    /// Blob URLs have the format `blob:origin/uuid`, so we try to extract
    /// any meaningful identifier. Falls back to the UUID if available.
    ///
    /// - Parameter url: The blob URL.
    /// - Returns: An extracted filename or nil.
    private func extractFilename(from url: URL) -> String? {
        // blob URLs are like blob:https://example.com/uuid
        // Try to get the last path component (UUID)
        let urlString = url.absoluteString

        // Remove the "blob:" prefix and parse as URL
        if urlString.hasPrefix("blob:") {
            let inner = String(urlString.dropFirst(5))
            if let innerURL = URL(string: inner) {
                let lastComponent = innerURL.lastPathComponent
                if !lastComponent.isEmpty, lastComponent != "/" {
                    return lastComponent
                }
            }
        }

        return nil
    }

    /// Ensures a filename has an appropriate extension based on MIME type.
    ///
    /// - Parameters:
    ///   - filename: The original filename.
    ///   - mimeType: The MIME type of the data.
    /// - Returns: Filename with appropriate extension.
    private func ensureFileExtension(_ filename: String, mimeType: String) -> String {
        // If already has an extension, keep it
        let pathExtension = (filename as NSString).pathExtension
        if !pathExtension.isEmpty {
            return filename
        }

        // Map common MIME types to extensions
        let extensionMap: [String: String] = [
            "application/pdf": "pdf",
            "application/json": "json",
            "application/zip": "zip",
            "application/xml": "xml",
            "application/octet-stream": "bin",
            "text/plain": "txt",
            "text/html": "html",
            "text/css": "css",
            "text/javascript": "js",
            "text/csv": "csv",
            "image/png": "png",
            "image/jpeg": "jpg",
            "image/gif": "gif",
            "image/webp": "webp",
            "image/svg+xml": "svg",
            "audio/mpeg": "mp3",
            "audio/wav": "wav",
            "audio/ogg": "ogg",
            "video/mp4": "mp4",
            "video/webm": "webm",
            "video/quicktime": "mov",
        ]

        if let ext = extensionMap[mimeType.lowercased()] {
            return "\(filename).\(ext)"
        }

        // Try to extract from MIME type (e.g., "image/png" -> "png")
        if let slashIndex = mimeType.lastIndex(of: "/") {
            let subtype = String(mimeType[mimeType.index(after: slashIndex)...])
            // Remove any parameters (e.g., "svg+xml" -> "svg")
            let cleanSubtype = subtype.components(separatedBy: CharacterSet(charactersIn: "+;")).first ?? subtype
            if !cleanSubtype.isEmpty {
                return "\(filename).\(cleanSubtype)"
            }
        }

        return filename
    }

    /// Saves base64-encoded blob data to a file.
    ///
    /// - Parameters:
    ///   - base64Data: The base64-encoded data.
    ///   - filename: The filename to save as.
    private func saveBlobData(_ base64Data: String, filename: String) {
        guard let data = Data(base64Encoded: base64Data) else {
            reportCompletion(.failure(.downloadFailed("Invalid base64 data")))
            return
        }

        do {
            let destination = try destinationURL(for: filename)

            // Remove existing file if replacing
            if replaceExistingFiles {
                removeExistingFile(at: destination)
            }

            // Update download info
            currentDownloadInfo = DownloadInfo(
                filename: filename,
                destinationURL: destination,
                progress: 0.5,
                bytesReceived: Int64(data.count),
                totalBytes: Int64(data.count)
            )

            // Write the data
            try data.write(to: destination, options: .atomic)

            progress = 1.0
            reportCompletion(.success(destination))

        } catch let error as DownloadError {
            reportCompletion(.failure(error))
        } catch {
            reportCompletion(.failure(.downloadFailed(error.localizedDescription)))
        }
    }
}

// MARK: - Convenience Extensions

extension DownloadHandler {
    /// Creates a download handler configured for the app's Documents directory.
    public static func documentsHandler() -> DownloadHandler {
        DownloadHandler(downloadsDirectory: nil)
    }

    /// Creates a download handler for a specific subdirectory within Documents.
    ///
    /// - Parameter subdirectory: The subdirectory name within Documents.
    /// - Returns: A configured download handler.
    public static func handler(forSubdirectory subdirectory: String) -> DownloadHandler {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        let downloadURL = documentsURL?.appendingPathComponent(subdirectory)
        return DownloadHandler(downloadsDirectory: downloadURL)
    }
}

// MARK: - Combine Convenience

extension DownloadHandler {
    /// A publisher that combines all download state into a single struct.
    public struct DownloadState: Sendable {
        public let isDownloading: Bool
        public let progress: Double
        public let info: DownloadInfo?
    }

    /// Publisher for combined download state.
    public var downloadStatePublisher: AnyPublisher<DownloadState, Never> {
        Publishers.CombineLatest3(
            isDownloadingSubject,
            progressSubject,
            downloadInfoSubject
        )
        .map { isDownloading, progress, info in
            DownloadState(isDownloading: isDownloading, progress: progress, info: info)
        }
        .eraseToAnyPublisher()
    }
}
