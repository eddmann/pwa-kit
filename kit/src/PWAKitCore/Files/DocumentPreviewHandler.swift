import UIKit

// MARK: - DocumentPreviewHandler

/// Handles document preview and sharing using `UIDocumentInteractionController`.
///
/// `DocumentPreviewHandler` provides a simple interface for previewing files
/// after download. It supports all file types that iOS can preview natively,
/// and provides sharing capabilities through the system share sheet.
///
/// ## Usage
///
/// Create a handler and present the preview:
/// ```swift
/// let handler = DocumentPreviewHandler()
/// handler.presentPreview(for: fileURL, from: viewController)
/// ```
///
/// For more control, use the async version:
/// ```swift
/// let result = await handler.preview(fileURL: fileURL, from: viewController)
/// switch result {
/// case .previewed:
///     print("User viewed the document")
/// case .shared:
///     print("User shared the document")
/// case .dismissed:
///     print("User dismissed without action")
/// case .cannotPreview:
///     print("File type not supported for preview")
/// case .error(let error):
///     print("Error: \(error)")
/// }
/// ```
///
/// ## Supported File Types
///
/// iOS can preview many common file types including:
/// - Documents: PDF, RTF, plain text
/// - Images: JPEG, PNG, GIF, HEIC
/// - Audio: MP3, WAV, M4A
/// - Video: MP4, MOV, M4V
/// - Office: Word, Excel, PowerPoint (with Quick Look)
/// - Archives: ZIP (shows contents)
///
/// ## Thread Safety
///
/// This class must be used from the main thread as it presents UI.
@MainActor
public final class DocumentPreviewHandler: NSObject {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates a new document preview handler.
    override public init() {
        super.init()
    }

    // MARK: Public

    // MARK: - Types

    /// The result of a document preview interaction.
    public enum PreviewResult: Sendable {
        /// The document was previewed successfully.
        case previewed
        /// The document was shared via the share sheet.
        case shared
        /// The user dismissed the preview without action.
        case dismissed
        /// The document type cannot be previewed.
        case cannotPreview
        /// An error occurred during preview.
        case error(String)
    }

    /// Errors that can occur during document preview.
    public enum PreviewError: Error, LocalizedError, Sendable {
        /// The file does not exist at the specified URL.
        case fileNotFound
        /// The file type is not supported for preview.
        case unsupportedFileType
        /// No view controller available for presentation.
        case noViewControllerAvailable
        /// The preview could not be presented.
        case cannotPresent

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .fileNotFound:
                "File not found"
            case .unsupportedFileType:
                "File type not supported for preview"
            case .noViewControllerAvailable:
                "No view controller available"
            case .cannotPresent:
                "Cannot present preview"
            }
        }
    }

    // MARK: - Public API

    /// Presents a preview for the document at the specified URL.
    ///
    /// This method attempts to preview the document using Quick Look.
    /// If the file type cannot be previewed, it falls back to showing
    /// sharing options.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to preview.
    ///   - viewController: The view controller to present from.
    /// - Returns: Whether the preview was presented successfully.
    @discardableResult
    public func presentPreview(for fileURL: URL, from viewController: UIViewController) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        // Clean up any existing controller
        documentController = nil

        // Create new controller
        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        documentController = controller
        presentingViewController = viewController

        // Try to present preview
        if controller.presentPreview(animated: true) {
            return true
        }

        // Fall back to options menu if preview not available
        return controller.presentOptionsMenu(
            from: viewController.view.bounds,
            in: viewController.view,
            animated: true
        )
    }

    /// Presents a preview for the document with async result.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to preview.
    ///   - viewController: The view controller to present from.
    /// - Returns: The result of the preview interaction.
    public func preview(fileURL: URL, from viewController: UIViewController) async -> PreviewResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .error(PreviewError.fileNotFound.localizedDescription)
        }

        return await withCheckedContinuation { continuation in
            // Cancel any pending continuation
            previewContinuation?.resume(returning: .dismissed)
            previewContinuation = continuation

            didPreview = false
            didShare = false

            // Clean up any existing controller
            documentController = nil

            // Create new controller
            let controller = UIDocumentInteractionController(url: fileURL)
            controller.delegate = self
            documentController = controller
            presentingViewController = viewController

            // Try to present preview
            if controller.presentPreview(animated: true) {
                didPreview = true
                return
            }

            // Fall back to options menu if preview not available
            if controller.presentOptionsMenu(
                from: viewController.view.bounds,
                in: viewController.view,
                animated: true
            ) {
                return
            }

            // Cannot present at all
            previewContinuation?.resume(returning: .cannotPreview)
            previewContinuation = nil
        }
    }

    /// Shows the share sheet for the document.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file to share.
    ///   - viewController: The view controller to present from.
    ///   - sourceRect: The source rect for the popover on iPad.
    /// - Returns: Whether the share sheet was presented.
    @discardableResult
    public func presentShareSheet(
        for fileURL: URL,
        from viewController: UIViewController,
        sourceRect: CGRect? = nil
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        // Clean up any existing controller
        documentController = nil

        // Create new controller
        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        documentController = controller
        presentingViewController = viewController

        let rect = sourceRect ?? CGRect(
            x: viewController.view.bounds.midX,
            y: viewController.view.bounds.midY,
            width: 0,
            height: 0
        )
        return controller.presentOptionsMenu(from: rect, in: viewController.view, animated: true)
    }

    /// Presents an "Open In..." menu for the document.
    ///
    /// This shows apps that can open the document type.
    ///
    /// - Parameters:
    ///   - fileURL: The URL of the file.
    ///   - viewController: The view controller to present from.
    ///   - sourceRect: The source rect for the popover on iPad.
    /// - Returns: Whether the menu was presented (false if no apps available).
    @discardableResult
    public func presentOpenInMenu(
        for fileURL: URL,
        from viewController: UIViewController,
        sourceRect: CGRect? = nil
    ) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        // Clean up any existing controller
        documentController = nil

        // Create new controller
        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        documentController = controller
        presentingViewController = viewController

        let rect = sourceRect ?? CGRect(
            x: viewController.view.bounds.midX,
            y: viewController.view.bounds.midY,
            width: 0,
            height: 0
        )
        return controller.presentOpenInMenu(from: rect, in: viewController.view, animated: true)
    }

    /// Checks if a file type can be previewed.
    ///
    /// - Parameter fileURL: The URL of the file to check.
    /// - Returns: Whether the file can be previewed.
    public func canPreview(fileURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return false
        }

        // Create a temporary controller to check
        let controller = UIDocumentInteractionController(url: fileURL)
        // Check if icons are available (indicates system knows about the type)
        return !controller.icons.isEmpty
    }

    /// Dismisses any currently presented preview.
    ///
    /// - Parameter animated: Whether to animate the dismissal.
    public func dismissPreview(animated: Bool = true) {
        documentController?.dismissPreview(animated: animated)
        documentController?.dismissMenu(animated: animated)
    }

    // MARK: Private

    // MARK: - Private Properties

    /// The document interaction controller for the current preview.
    private var documentController: UIDocumentInteractionController?

    /// Continuation for async preview result.
    private var previewContinuation: CheckedContinuation<PreviewResult, Never>?

    /// Whether a preview was successfully displayed.
    private var didPreview = false

    /// Whether sharing options were opened.
    private var didShare = false

    /// The presenting view controller.
    private weak var presentingViewController: UIViewController?
}

// MARK: UIDocumentInteractionControllerDelegate

extension DocumentPreviewHandler: UIDocumentInteractionControllerDelegate {
    // MARK: Public

    /// Provides the view controller for presenting the preview.
    public nonisolated func documentInteractionControllerViewControllerForPreview(
        _: UIDocumentInteractionController
    ) -> UIViewController {
        // Must dispatch to main actor to access presentingViewController
        // But this delegate method is synchronous, so we return a safe default
        // The actual presenting VC is set when we call presentPreview
        MainActor.assumeIsolated {
            presentingViewController ?? UIViewController()
        }
    }

    /// Called when the preview will begin.
    public nonisolated func documentInteractionControllerWillBeginPreview(
        _: UIDocumentInteractionController
    ) {
        Task { @MainActor in
            didPreview = true
        }
    }

    /// Called when the preview has ended.
    public nonisolated func documentInteractionControllerDidEndPreview(
        _: UIDocumentInteractionController
    ) {
        Task { @MainActor in
            if let continuation = previewContinuation {
                if didShare {
                    continuation.resume(returning: .shared)
                } else if didPreview {
                    continuation.resume(returning: .previewed)
                } else {
                    continuation.resume(returning: .dismissed)
                }
                previewContinuation = nil
            }
            cleanup()
        }
    }

    /// Called when the options menu will begin.
    public nonisolated func documentInteractionControllerWillPresentOptionsMenu(
        _: UIDocumentInteractionController
    ) {
        // Options menu is about to show
    }

    /// Called when the options menu has ended.
    public nonisolated func documentInteractionControllerDidDismissOptionsMenu(
        _: UIDocumentInteractionController
    ) {
        Task { @MainActor in
            if let continuation = previewContinuation {
                if didShare {
                    continuation.resume(returning: .shared)
                } else {
                    continuation.resume(returning: .dismissed)
                }
                previewContinuation = nil
            }
            cleanup()
        }
    }

    /// Called when the open-in menu will begin.
    public nonisolated func documentInteractionControllerWillPresentOpenInMenu(
        _: UIDocumentInteractionController
    ) {
        // Open-in menu is about to show
    }

    /// Called when the open-in menu has ended.
    public nonisolated func documentInteractionControllerDidDismissOpenInMenu(
        _: UIDocumentInteractionController
    ) {
        Task { @MainActor in
            if let continuation = previewContinuation {
                if didShare {
                    continuation.resume(returning: .shared)
                } else {
                    continuation.resume(returning: .dismissed)
                }
                previewContinuation = nil
            }
            cleanup()
        }
    }

    /// Called when the document will be opened by another application.
    public nonisolated func documentInteractionController(
        _: UIDocumentInteractionController,
        willBeginSendingToApplication _: String?
    ) {
        Task { @MainActor in
            didShare = true
        }
    }

    /// Called after the document was sent to another application.
    public nonisolated func documentInteractionController(
        _: UIDocumentInteractionController,
        didEndSendingToApplication _: String?
    ) {
        Task { @MainActor in
            didShare = true
        }
    }

    // MARK: Private

    // MARK: - Private Methods

    /// Cleans up resources after preview is complete.
    private func cleanup() {
        documentController = nil
        didPreview = false
        didShare = false
    }
}

// MARK: - Convenience Extensions

extension DocumentPreviewHandler {
    /// Common document types that can be previewed.
    public enum DocumentType: String, CaseIterable, Sendable {
        case pdf
        case text = "txt"
        case rtf
        case html
        case png
        case jpeg = "jpg"
        case gif
        case heic
        case mp3
        case mp4
        case mov
        case zip
        case doc
        case docx
        case xls
        case xlsx
        case ppt
        case pptx
        case csv
        case json
        case xml

        // MARK: Public

        /// The UTI for this document type.
        public var uniformTypeIdentifier: String {
            switch self {
            case .pdf: "com.adobe.pdf"
            case .text: "public.plain-text"
            case .rtf: "public.rtf"
            case .html: "public.html"
            case .png: "public.png"
            case .jpeg: "public.jpeg"
            case .gif: "com.compuserve.gif"
            case .heic: "public.heic"
            case .mp3: "public.mp3"
            case .mp4: "public.mpeg-4"
            case .mov: "com.apple.quicktime-movie"
            case .zip: "public.zip-archive"
            case .doc: "com.microsoft.word.doc"
            case .docx: "org.openxmlformats.wordprocessingml.document"
            case .xls: "com.microsoft.excel.xls"
            case .xlsx: "org.openxmlformats.spreadsheetml.sheet"
            case .ppt: "com.microsoft.powerpoint.ppt"
            case .pptx: "org.openxmlformats.presentationml.presentation"
            case .csv: "public.comma-separated-values-text"
            case .json: "public.json"
            case .xml: "public.xml"
            }
        }
    }

    /// Determines the document type from a file URL.
    ///
    /// - Parameter fileURL: The URL of the file.
    /// - Returns: The document type, or nil if unknown.
    public static func documentType(for fileURL: URL) -> DocumentType? {
        let ext = fileURL.pathExtension.lowercased()
        return DocumentType(rawValue: ext)
    }

    /// Sets the document name to display in the preview.
    ///
    /// - Parameter name: The name to display.
    public func setDocumentName(_ name: String) {
        documentController?.name = name
    }
}

// MARK: - Integration with DownloadHandler

extension DocumentPreviewHandler {
    /// Presents a preview for a download result.
    ///
    /// This convenience method integrates with `DownloadHandler.DownloadResult`.
    ///
    /// - Parameters:
    ///   - downloadURL: The URL of the downloaded file.
    ///   - viewController: The view controller to present from.
    /// - Returns: Whether the preview was presented.
    @discardableResult
    public func presentPreview(forDownloadedFile downloadURL: URL, from viewController: UIViewController) -> Bool {
        presentPreview(for: downloadURL, from: viewController)
    }
}
