import Foundation
@testable import PWAKitApp
import Testing
import UIKit

// MARK: - ClipboardModuleTests

@Suite("ClipboardModule Tests", .serialized)
struct ClipboardModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(ClipboardModule.moduleName == "clipboard")
    }

    @Test("Supports write and read actions")
    func supportsExpectedActions() {
        #expect(ClipboardModule.supportedActions == ["write", "read"])
        #expect(ClipboardModule.supports(action: "write"))
        #expect(ClipboardModule.supports(action: "read"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!ClipboardModule.supports(action: "unknown"))
        #expect(!ClipboardModule.supports(action: "copy"))
        #expect(!ClipboardModule.supports(action: "paste"))
        #expect(!ClipboardModule.supports(action: ""))
    }

    // MARK: - Write Action

    @Test("write action copies text to clipboard")
    @MainActor
    func writeActionCopiesToClipboard() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()
        let testText = "Test clipboard content \(UUID().uuidString)"

        let result = try await module.handle(
            action: "write",
            payload: AnyCodable(["text": AnyCodable(testText)]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["copied"]?.boolValue == true)
        // Verify the text was actually copied
        #expect(UIPasteboard.general.string == testText)
    }

    @Test("write action throws for missing text")
    @MainActor
    func writeThrowsForMissingText() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()

        // Test with nil payload
        do {
            _ = try await module.handle(
                action: "write",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("text"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("write action throws for empty payload")
    @MainActor
    func writeThrowsForEmptyPayload() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()

        // Test with empty payload (no text field)
        do {
            _ = try await module.handle(
                action: "write",
                payload: AnyCodable(["other": AnyCodable("value")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("text"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("write action handles empty string")
    @MainActor
    func writeHandlesEmptyString() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "write",
            payload: AnyCodable(["text": AnyCodable("")]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["copied"]?.boolValue == true)
        #expect(UIPasteboard.general.string == "")
    }

    // MARK: - Read Action

    @Test("read action returns clipboard content")
    @MainActor
    func readActionReturnsClipboardContent() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()
        let testText = "Read test \(UUID().uuidString)"
        // Set up clipboard content
        UIPasteboard.general.string = testText
        let result = try await module.handle(
            action: "read",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["text"]?.stringValue == testText)
    }

    @Test("read action returns null for empty clipboard")
    @MainActor
    func readReturnsNullForEmptyClipboard() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()
        // Clear clipboard
        UIPasteboard.general.string = nil
        let result = try await module.handle(
            action: "read",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        // When clipboard is empty, text should be null
        #expect(dict?["text"] != nil)
        if let textValue = dict?["text"] {
            #expect(textValue.isNull || textValue.stringValue == "")
        }
    }

    @Test("read action ignores payload")
    @MainActor
    func readIgnoresPayload() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()
        let testText = "Ignore payload test \(UUID().uuidString)"
        UIPasteboard.general.string = testText
        // Passing payload should not affect read behavior
        let result = try await module.handle(
            action: "read",
            payload: AnyCodable(["irrelevant": AnyCodable("data")]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["text"]?.stringValue == testText)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = ClipboardModule()
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
        let module = ClipboardModule()
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

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = ClipboardModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(ClipboardModule.moduleName == "clipboard")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = ClipboardModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(ClipboardModule.moduleName == "clipboard")
        #expect(!ClipboardModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = ClipboardModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = ClipboardModule()

        try module.validateAction("write")
        try module.validateAction("read")
        // Should not throw
    }

    // MARK: - Round Trip Tests

    @Test("write then read returns same text")
    @MainActor
    func writeReadRoundTrip() async throws {
        let module = ClipboardModule()
        let context = ModuleContext()
        let testText = "Round trip test \(UUID().uuidString)"

        // Write to clipboard
        _ = try await module.handle(
            action: "write",
            payload: AnyCodable(["text": AnyCodable(testText)]),
            context: context
        )

        // Read from clipboard
        let result = try await module.handle(
            action: "read",
            payload: nil,
            context: context
        )
        let dict = result?.dictionaryValue
        #expect(dict?["text"]?.stringValue == testText)
    }
}
