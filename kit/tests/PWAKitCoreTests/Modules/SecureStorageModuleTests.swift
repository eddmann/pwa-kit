import Foundation
@testable import PWAKitApp
import Testing

@Suite("SecureStorageModule Tests")
struct SecureStorageModuleTests {
    /// Test service name to avoid conflicts with real app data.
    private let testService = "com.pwakit.tests.securestorage"

    /// Creates a fresh SecureStorageModule for testing with isolated keychain.
    private func makeModule() -> SecureStorageModule {
        let keychain = KeychainHelper(service: testService)
        return SecureStorageModule(keychain: keychain)
    }

    /// Creates a fresh KeychainHelper for cleanup.
    private func makeKeychain() -> KeychainHelper {
        KeychainHelper(service: testService)
    }

    /// Cleans up a test key from the Keychain.
    private func cleanup(key: String) {
        try? makeKeychain().delete(forKey: key)
    }

    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(SecureStorageModule.moduleName == "secureStorage")
    }

    @Test("Supports set, get, and delete actions")
    func supportsExpectedActions() {
        #expect(SecureStorageModule.supportedActions == ["set", "get", "delete"])
        #expect(SecureStorageModule.supports(action: "set"))
        #expect(SecureStorageModule.supports(action: "get"))
        #expect(SecureStorageModule.supports(action: "delete"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!SecureStorageModule.supports(action: "unknown"))
        #expect(!SecureStorageModule.supports(action: "save"))
        #expect(!SecureStorageModule.supports(action: "remove"))
        #expect(!SecureStorageModule.supports(action: ""))
    }

    // MARK: - set Action

    @Test("Set stores a value successfully")
    @MainActor
    func setStoresValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-set-\(UUID().uuidString)"
        defer { cleanup(key: testKey) }

        let result = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable("test-value"),
            ]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["success"]?.boolValue == true)
    }

    @Test("Set updates existing value")
    @MainActor
    func setUpdatesExistingValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-update-\(UUID().uuidString)"
        defer { cleanup(key: testKey) }

        // Set initial value
        _ = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable("initial-value"),
            ]),
            context: context
        )

        // Update value
        let result = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable("updated-value"),
            ]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict?["success"]?.boolValue == true)

        // Verify the update took effect
        let getResult = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        #expect(getResult?.dictionaryValue?["value"]?.stringValue == "updated-value")
    }

    @Test("Set throws error for missing key")
    @MainActor
    func setThrowsForMissingKey() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "set",
                payload: AnyCodable(["value": AnyCodable("test")]),
                context: context
            )
        }
    }

    @Test("Set throws error for empty key")
    @MainActor
    func setThrowsForEmptyKey() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "set",
                payload: AnyCodable([
                    "key": AnyCodable(""),
                    "value": AnyCodable("test"),
                ]),
                context: context
            )
        }
    }

    @Test("Set throws error for missing value")
    @MainActor
    func setThrowsForMissingValue() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "set",
                payload: AnyCodable(["key": AnyCodable("test-key")]),
                context: context
            )
        }
    }

    @Test("Set throws error for nil payload")
    @MainActor
    func setThrowsForNilPayload() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "set",
                payload: nil,
                context: context
            )
        }
    }

    @Test("Set handles empty string value")
    @MainActor
    func setHandlesEmptyStringValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-empty-value-\(UUID().uuidString)"
        defer { cleanup(key: testKey) }

        let result = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable(""),
            ]),
            context: context
        )

        #expect(result?.dictionaryValue?["success"]?.boolValue == true)

        // Verify empty string was stored
        let getResult = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        #expect(getResult?.dictionaryValue?["value"]?.stringValue == "")
    }

    // MARK: - get Action

    @Test("Get retrieves a stored value")
    @MainActor
    func getRetrievesValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-get-\(UUID().uuidString)"
        let testValue = "secret-token-12345"
        defer { cleanup(key: testKey) }

        // Store value first
        _ = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable(testValue),
            ]),
            context: context
        )

        // Retrieve value
        let result = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["value"]?.stringValue == testValue)
    }

    @Test("Get returns null for non-existent key")
    @MainActor
    func getReturnsNullForNonExistent() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-non-existent-\(UUID().uuidString)"

        let result = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["value"]?.isNull == true)
    }

    @Test("Get throws error for missing key")
    @MainActor
    func getThrowsForMissingKey() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "get",
                payload: AnyCodable([:]),
                context: context
            )
        }
    }

    @Test("Get throws error for empty key")
    @MainActor
    func getThrowsForEmptyKey() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "get",
                payload: AnyCodable(["key": AnyCodable("")]),
                context: context
            )
        }
    }

    @Test("Get throws error for nil payload")
    @MainActor
    func getThrowsForNilPayload() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "get",
                payload: nil,
                context: context
            )
        }
    }

    // MARK: - delete Action

    @Test("Delete removes a stored value")
    @MainActor
    func deleteRemovesValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-delete-\(UUID().uuidString)"
        defer { cleanup(key: testKey) }

        // Store value first
        _ = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable("to-be-deleted"),
            ]),
            context: context
        )

        // Delete value
        let result = try await module.handle(
            action: "delete",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict?["success"]?.boolValue == true)

        // Verify deletion
        let getResult = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        #expect(getResult?.dictionaryValue?["value"]?.isNull == true)
    }

    @Test("Delete succeeds for non-existent key")
    @MainActor
    func deleteSucceedsForNonExistent() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-delete-non-existent-\(UUID().uuidString)"

        let result = try await module.handle(
            action: "delete",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict?["success"]?.boolValue == true)
    }

    @Test("Delete throws error for missing key")
    @MainActor
    func deleteThrowsForMissingKey() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "delete",
                payload: AnyCodable([:]),
                context: context
            )
        }
    }

    @Test("Delete throws error for empty key")
    @MainActor
    func deleteThrowsForEmptyKey() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "delete",
                payload: AnyCodable(["key": AnyCodable("")]),
                context: context
            )
        }
    }

    @Test("Delete throws error for nil payload")
    @MainActor
    func deleteThrowsForNilPayload() async {
        let module = makeModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "delete",
                payload: nil,
                context: context
            )
        }
    }

    // MARK: - Special Characters

    @Test("Handles special characters in value")
    @MainActor
    func handlesSpecialCharactersInValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-special-\(UUID().uuidString)"
        let testValue = "Hello! @#$%^&*()_+=[]{}|;':\",./<>?"
        defer { cleanup(key: testKey) }

        _ = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable(testValue),
            ]),
            context: context
        )

        let result = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        #expect(result?.dictionaryValue?["value"]?.stringValue == testValue)
    }

    @Test("Handles unicode characters in value")
    @MainActor
    func handlesUnicodeInValue() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey = "test-unicode-\(UUID().uuidString)"
        let testValue = "Hello, World!"
        defer { cleanup(key: testKey) }

        _ = try await module.handle(
            action: "set",
            payload: AnyCodable([
                "key": AnyCodable(testKey),
                "value": AnyCodable(testValue),
            ]),
            context: context
        )

        let result = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey)]),
            context: context
        )

        #expect(result?.dictionaryValue?["value"]?.stringValue == testValue)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async {
        let module = makeModule()
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
        let module = makeModule()
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
        let module = makeModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            #expect(SecureStorageModule.moduleName == "secureStorage")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = makeModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(SecureStorageModule.moduleName == "secureStorage")
        #expect(!SecureStorageModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = makeModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = makeModule()

        try module.validateAction("set")
        try module.validateAction("get")
        try module.validateAction("delete")
        // Should not throw
    }

    // MARK: - Multiple Keys Tests

    @Test("Multiple keys are independent")
    @MainActor
    func multipleKeysIndependent() async throws {
        let module = makeModule()
        let context = ModuleContext()
        let testKey1 = "test-multi-key-1-\(UUID().uuidString)"
        let testKey2 = "test-multi-key-2-\(UUID().uuidString)"
        defer {
            cleanup(key: testKey1)
            cleanup(key: testKey2)
        }

        let value1 = "value-for-key-1"
        let value2 = "value-for-key-2"

        // Store both values
        _ = try await module.handle(
            action: "set",
            payload: AnyCodable(["key": AnyCodable(testKey1), "value": AnyCodable(value1)]),
            context: context
        )
        _ = try await module.handle(
            action: "set",
            payload: AnyCodable(["key": AnyCodable(testKey2), "value": AnyCodable(value2)]),
            context: context
        )

        // Verify both values are stored independently
        let result1 = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey1)]),
            context: context
        )
        let result2 = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey2)]),
            context: context
        )

        #expect(result1?.dictionaryValue?["value"]?.stringValue == value1)
        #expect(result2?.dictionaryValue?["value"]?.stringValue == value2)

        // Delete key1 and verify key2 is unaffected
        _ = try await module.handle(
            action: "delete",
            payload: AnyCodable(["key": AnyCodable(testKey1)]),
            context: context
        )

        let result1After = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey1)]),
            context: context
        )
        let result2After = try await module.handle(
            action: "get",
            payload: AnyCodable(["key": AnyCodable(testKey2)]),
            context: context
        )

        #expect(result1After?.dictionaryValue?["value"]?.isNull == true)
        #expect(result2After?.dictionaryValue?["value"]?.stringValue == value2)
    }

    // MARK: - Default Initialization

    @Test("Default initialization uses default keychain")
    func defaultInitialization() {
        let module = SecureStorageModule()
        // Should not crash and conform to protocol
        let _: any PWAModule = module
        #expect(SecureStorageModule.moduleName == "secureStorage")
    }
}
