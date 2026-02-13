import Foundation
@testable import PWAKitApp
import Testing
import UIKit

// MARK: - ShareModuleTests

@Suite("ShareModule Tests")
struct ShareModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(ShareModule.moduleName == "share")
    }

    @Test("Supports share and canShare actions")
    func supportsExpectedActions() {
        #expect(ShareModule.supportedActions == ["share", "canShare"])
        #expect(ShareModule.supports(action: "share"))
        #expect(ShareModule.supports(action: "canShare"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!ShareModule.supports(action: "unknown"))
        #expect(!ShareModule.supports(action: "send"))
        #expect(!ShareModule.supports(action: ""))
    }

    // MARK: - ShareFile Parsing

    @Test("Parses valid file payload")
    func parsesValidFilePayload() {
        let base64Data = Data("Hello, World!".utf8).base64EncodedString()
        let payload = AnyCodable([
            "name": AnyCodable("test.txt"),
            "type": AnyCodable("text/plain"),
            "data": AnyCodable(base64Data),
        ])

        let file = ShareModule.ShareFile.from(payload: payload)

        #expect(file != nil)
        #expect(file?.name == "test.txt")
        #expect(file?.type == "text/plain")
        #expect(file?.data == Data("Hello, World!".utf8))
    }

    @Test("Returns nil for missing name")
    func returnsNilForMissingName() {
        let base64Data = Data("test".utf8).base64EncodedString()
        let payload = AnyCodable([
            "type": AnyCodable("text/plain"),
            "data": AnyCodable(base64Data),
        ])

        let file = ShareModule.ShareFile.from(payload: payload)
        #expect(file == nil)
    }

    @Test("Returns nil for missing type")
    func returnsNilForMissingType() {
        let base64Data = Data("test".utf8).base64EncodedString()
        let payload = AnyCodable([
            "name": AnyCodable("test.txt"),
            "data": AnyCodable(base64Data),
        ])

        let file = ShareModule.ShareFile.from(payload: payload)
        #expect(file == nil)
    }

    @Test("Returns nil for missing data")
    func returnsNilForMissingData() {
        let payload = AnyCodable([
            "name": AnyCodable("test.txt"),
            "type": AnyCodable("text/plain"),
        ])

        let file = ShareModule.ShareFile.from(payload: payload)
        #expect(file == nil)
    }

    @Test("Returns nil for invalid base64 data")
    func returnsNilForInvalidBase64() {
        let payload = AnyCodable([
            "name": AnyCodable("test.txt"),
            "type": AnyCodable("text/plain"),
            "data": AnyCodable("not-valid-base64!!!"),
        ])

        let file = ShareModule.ShareFile.from(payload: payload)
        #expect(file == nil)
    }

    @Test("Returns nil for nil payload")
    func returnsNilForNilPayload() {
        let file = ShareModule.ShareFile.from(payload: nil)
        #expect(file == nil)
    }

    @Test("Decodes various base64 encoded files")
    func decodesVariousBase64Files() {
        // Test PDF-like binary data
        let pdfData = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
        let pdfPayload = AnyCodable([
            "name": AnyCodable("document.pdf"),
            "type": AnyCodable("application/pdf"),
            "data": AnyCodable(pdfData.base64EncodedString()),
        ])
        let pdfFile = ShareModule.ShareFile.from(payload: pdfPayload)
        #expect(pdfFile != nil)
        #expect(pdfFile?.data == pdfData)

        // Test image-like binary data
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        let imagePayload = AnyCodable([
            "name": AnyCodable("image.png"),
            "type": AnyCodable("image/png"),
            "data": AnyCodable(imageData.base64EncodedString()),
        ])
        let imageFile = ShareModule.ShareFile.from(payload: imagePayload)
        #expect(imageFile != nil)
        #expect(imageFile?.data == imageData)
    }

    // MARK: - canShare Action

    @Test("canShare returns expected value based on platform")
    @MainActor
    func canShareReturnsExpectedValue() async throws {
        let module = ShareModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "canShare",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["available"]?.boolValue != nil)

        // On iOS, available should be true
        #expect(dict?["available"]?.boolValue == true)
    }

    @Test("canShare ignores payload")
    @MainActor
    func canShareIgnoresPayload() async throws {
        let module = ShareModule()
        let context = ModuleContext()

        let resultWithPayload = try await module.handle(
            action: "canShare",
            payload: AnyCodable(["ignored": AnyCodable("value")]),
            context: context
        )

        let resultWithoutPayload = try await module.handle(
            action: "canShare",
            payload: nil,
            context: context
        )

        #expect(resultWithPayload == resultWithoutPayload)
    }

    // MARK: - share Action Validation

    @Test("share action throws for empty payload")
    @MainActor
    func shareThrowsForEmptyPayload() async {
        let module = ShareModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "share",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("No content to share"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("share action throws for empty content object")
    @MainActor
    func shareThrowsForEmptyContentObject() async {
        let module = ShareModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "share",
                payload: AnyCodable([:]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("No content to share"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("share action handles missing view controller")
    @MainActor
    func shareHandlesMissingViewController() async throws {
        let module = ShareModule()
        let context = ModuleContext() // No view controller
        // Should throw an error due to missing view controller
        do {
            _ = try await module.handle(
                action: "share",
                payload: AnyCodable(["text": AnyCodable("Hello")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("view controller"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = ShareModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "unknownAction",
                payload: nil,
                context: context
            )
        }
    }

    @Test("Throws specific error for unknown action")
    @MainActor
    func throwsSpecificErrorForUnknownAction() async {
        let module = ShareModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "badAction",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            #expect(error == BridgeError.unknownAction("badAction"))
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - URL Sharing

    @Test("Accepts valid URL string")
    @MainActor
    func acceptsValidURLString() async {
        let module = ShareModule()
        let context = ModuleContext()

        // Without a view controller, this will fail at presentation time
        // but we can verify it doesn't throw for invalid URL
        do {
            _ = try await module.handle(
                action: "share",
                payload: AnyCodable(["url": AnyCodable("https://example.com")]),
                context: context
            )
        } catch let error as BridgeError {
            // Expected to fail due to missing view controller, not invalid URL
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("view controller"))
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Ignores invalid URL strings silently")
    @MainActor
    func ignoresInvalidURLStrings() async {
        let module = ShareModule()
        let context = ModuleContext()

        // Invalid URL with only text should still attempt to share the text
        do {
            _ = try await module.handle(
                action: "share",
                payload: AnyCodable([
                    "url": AnyCodable("not a valid url"),
                    "text": AnyCodable("Some text to share"),
                ]),
                context: context
            )
        } catch let error as BridgeError {
            // Expected to fail due to missing view controller
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("view controller"))
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Text Sharing

    @Test("Accepts text content")
    @MainActor
    func acceptsTextContent() async {
        let module = ShareModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "share",
                payload: AnyCodable(["text": AnyCodable("Hello, World!")]),
                context: context
            )
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("view controller"))
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Accepts combined text and URL")
    @MainActor
    func acceptsCombinedTextAndURL() async {
        let module = ShareModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "share",
                payload: AnyCodable([
                    "text": AnyCodable("Check this out!"),
                    "url": AnyCodable("https://example.com"),
                ]),
                context: context
            )
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("view controller"))
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = ShareModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(ShareModule.moduleName == "share")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = ShareModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(ShareModule.moduleName == "share")
        #expect(!ShareModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = ShareModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = ShareModule()

        try module.validateAction("share")
        try module.validateAction("canShare")
        // Should not throw
    }

    // MARK: - ShareFile Struct

    @Test("ShareFile stores correct properties")
    func shareFileStoresProperties() {
        let testData = Data("test content".utf8)
        let file = ShareModule.ShareFile(
            name: "test.txt",
            type: "text/plain",
            data: testData
        )

        #expect(file.name == "test.txt")
        #expect(file.type == "text/plain")
        #expect(file.data == testData)
    }
}
