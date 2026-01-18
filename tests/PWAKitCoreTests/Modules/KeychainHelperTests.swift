import Foundation
import Testing

@testable import PWAKitApp

@Suite("KeychainHelper Tests")
struct KeychainHelperTests {
    /// Test service name to avoid conflicts with real app data.
    private let testService = "com.pwakit.tests.keychain"

    /// Creates a fresh KeychainHelper for testing.
    private func makeHelper() -> KeychainHelper {
        KeychainHelper(service: testService)
    }

    /// Cleans up a test key from the Keychain.
    private func cleanup(key: String, helper: KeychainHelper) {
        try? helper.delete(forKey: key)
    }

    // MARK: - Save and Retrieve Tests

    @Test("Save and retrieve a value")
    func saveAndRetrieve() throws {
        let helper = makeHelper()
        let testKey = "test-save-retrieve-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let testValue = "my-secret-value"

        try helper.save(testValue, forKey: testKey)
        let retrieved = try helper.retrieve(forKey: testKey)

        #expect(retrieved == testValue)
    }

    @Test("Save and retrieve empty string")
    func saveAndRetrieveEmptyString() throws {
        let helper = makeHelper()
        let testKey = "test-empty-string-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let testValue = ""

        try helper.save(testValue, forKey: testKey)
        let retrieved = try helper.retrieve(forKey: testKey)

        #expect(retrieved == testValue)
    }

    @Test("Save and retrieve special characters")
    func saveAndRetrieveSpecialCharacters() throws {
        let helper = makeHelper()
        let testKey = "test-special-chars-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let testValue = "Hello! @#$%^&*()_+=[]{}|;':\",./<>?"

        try helper.save(testValue, forKey: testKey)
        let retrieved = try helper.retrieve(forKey: testKey)

        #expect(retrieved == testValue)
    }

    @Test("Save and retrieve unicode characters")
    func saveAndRetrieveUnicode() throws {
        let helper = makeHelper()
        let testKey = "test-unicode-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let testValue = "Hello, World!"

        try helper.save(testValue, forKey: testKey)
        let retrieved = try helper.retrieve(forKey: testKey)

        #expect(retrieved == testValue)
    }

    @Test("Save and retrieve long string")
    func saveAndRetrieveLongString() throws {
        let helper = makeHelper()
        let testKey = "test-long-string-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let testValue = String(repeating: "a", count: 10000)

        try helper.save(testValue, forKey: testKey)
        let retrieved = try helper.retrieve(forKey: testKey)

        #expect(retrieved == testValue)
    }

    // MARK: - Update Existing Tests

    @Test("Update existing value")
    func updateExisting() throws {
        let helper = makeHelper()
        let testKey = "test-update-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let initialValue = "initial-value"
        let updatedValue = "updated-value"

        try helper.save(initialValue, forKey: testKey)
        let retrieved1 = try helper.retrieve(forKey: testKey)
        #expect(retrieved1 == initialValue)

        try helper.save(updatedValue, forKey: testKey)
        let retrieved2 = try helper.retrieve(forKey: testKey)
        #expect(retrieved2 == updatedValue)
    }

    @Test("Update existing value multiple times")
    func updateMultipleTimes() throws {
        let helper = makeHelper()
        let testKey = "test-multi-update-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        for i in 1 ... 5 {
            let value = "value-\(i)"
            try helper.save(value, forKey: testKey)
            let retrieved = try helper.retrieve(forKey: testKey)
            #expect(retrieved == value)
        }
    }

    // MARK: - Delete Tests

    @Test("Delete existing value")
    func deleteExisting() throws {
        let helper = makeHelper()
        let testKey = "test-delete-\(UUID().uuidString)"

        let testValue = "to-be-deleted"

        try helper.save(testValue, forKey: testKey)
        let retrieved1 = try helper.retrieve(forKey: testKey)
        #expect(retrieved1 == testValue)

        try helper.delete(forKey: testKey)
        let retrieved2 = try helper.retrieve(forKey: testKey)
        #expect(retrieved2 == nil)
    }

    @Test("Delete non-existent key does not throw")
    func deleteNonExistent() throws {
        let helper = makeHelper()
        let testKey = "test-delete-non-existent-\(UUID().uuidString)"

        // Should not throw
        try helper.delete(forKey: testKey)
    }

    @Test("Delete and re-save")
    func deleteAndResave() throws {
        let helper = makeHelper()
        let testKey = "test-delete-resave-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        let value1 = "first-value"
        let value2 = "second-value"

        try helper.save(value1, forKey: testKey)
        try helper.delete(forKey: testKey)
        try helper.save(value2, forKey: testKey)

        let retrieved = try helper.retrieve(forKey: testKey)
        #expect(retrieved == value2)
    }

    // MARK: - Not Found Tests

    @Test("Retrieve returns nil for non-existent key")
    func retrieveNonExistent() throws {
        let helper = makeHelper()
        let testKey = "test-non-existent-\(UUID().uuidString)"

        let retrieved = try helper.retrieve(forKey: testKey)
        #expect(retrieved == nil)
    }

    // MARK: - Multiple Keys Tests

    @Test("Multiple keys are independent")
    func multipleKeysIndependent() throws {
        let helper = makeHelper()
        let testKey1 = "test-multi-key-1-\(UUID().uuidString)"
        let testKey2 = "test-multi-key-2-\(UUID().uuidString)"
        defer {
            cleanup(key: testKey1, helper: helper)
            cleanup(key: testKey2, helper: helper)
        }

        let value1 = "value-for-key-1"
        let value2 = "value-for-key-2"

        try helper.save(value1, forKey: testKey1)
        try helper.save(value2, forKey: testKey2)

        #expect(try helper.retrieve(forKey: testKey1) == value1)
        #expect(try helper.retrieve(forKey: testKey2) == value2)

        try helper.delete(forKey: testKey1)
        #expect(try helper.retrieve(forKey: testKey1) == nil)
        #expect(try helper.retrieve(forKey: testKey2) == value2)
    }

    // MARK: - Different Service Tests

    @Test("Different services are isolated")
    func differentServicesIsolated() throws {
        let helper1 = KeychainHelper(service: "\(testService).service1")
        let helper2 = KeychainHelper(service: "\(testService).service2")
        let testKey = "test-same-key-\(UUID().uuidString)"
        defer {
            cleanup(key: testKey, helper: helper1)
            cleanup(key: testKey, helper: helper2)
        }

        let value1 = "value-from-service-1"
        let value2 = "value-from-service-2"

        try helper1.save(value1, forKey: testKey)
        try helper2.save(value2, forKey: testKey)

        #expect(try helper1.retrieve(forKey: testKey) == value1)
        #expect(try helper2.retrieve(forKey: testKey) == value2)
    }

    // MARK: - KeychainError Tests

    @Test("KeychainError has correct error descriptions")
    func keychainErrorDescriptions() {
        #expect(KeychainError.encodingFailed.localizedDescription.contains("encode"))
        #expect(KeychainError.decodingFailed.localizedDescription.contains("decode"))
        #expect(KeychainError.itemNotFound.localizedDescription.contains("not found"))
        #expect(KeychainError.accessDenied.localizedDescription.contains("denied"))
        #expect(KeychainError.duplicateItem.localizedDescription.contains("exists"))
        #expect(KeychainError.unexpectedError(-123).localizedDescription.contains("-123"))
    }

    @Test("KeychainError CustomStringConvertible")
    func keychainErrorDescription() {
        #expect(KeychainError.encodingFailed.description == "KeychainError.encodingFailed")
        #expect(KeychainError.decodingFailed.description == "KeychainError.decodingFailed")
        #expect(KeychainError.itemNotFound.description == "KeychainError.itemNotFound")
        #expect(KeychainError.accessDenied.description == "KeychainError.accessDenied")
        #expect(KeychainError.duplicateItem.description == "KeychainError.duplicateItem")
        #expect(KeychainError.unexpectedError(-123).description == "KeychainError.unexpectedError(-123)")
    }

    @Test("KeychainError from OSStatus maps correctly")
    func keychainErrorFromStatus() {
        #expect(KeychainError.from(status: errSecItemNotFound) == .itemNotFound)
        #expect(KeychainError.from(status: errSecAuthFailed) == .accessDenied)
        #expect(KeychainError.from(status: errSecInteractionNotAllowed) == .accessDenied)
        #expect(KeychainError.from(status: errSecDuplicateItem) == .duplicateItem)
        #expect(KeychainError.from(status: -99999) == .unexpectedError(-99999))
    }

    @Test("KeychainError Equatable")
    func keychainErrorEquatable() {
        #expect(KeychainError.encodingFailed == KeychainError.encodingFailed)
        #expect(KeychainError.decodingFailed == KeychainError.decodingFailed)
        #expect(KeychainError.itemNotFound == KeychainError.itemNotFound)
        #expect(KeychainError.accessDenied == KeychainError.accessDenied)
        #expect(KeychainError.duplicateItem == KeychainError.duplicateItem)
        #expect(KeychainError.unexpectedError(-1) == KeychainError.unexpectedError(-1))
        #expect(KeychainError.unexpectedError(-1) != KeychainError.unexpectedError(-2))
        #expect(KeychainError.encodingFailed != KeychainError.decodingFailed)
    }

    // MARK: - Initialization Tests

    @Test("Default service uses bundle identifier pattern")
    func defaultServiceInitialization() {
        let helper = KeychainHelper()
        // Service should not be empty
        #expect(!helper.service.isEmpty)
    }

    @Test("Custom service is respected")
    func customServiceInitialization() {
        let customService = "com.custom.service"
        let helper = KeychainHelper(service: customService)
        #expect(helper.service == customService)
    }

    @Test("Access group can be set")
    func accessGroupInitialization() {
        let accessGroup = "group.com.example.shared"
        let helper = KeychainHelper(service: testService, accessGroup: accessGroup)
        #expect(helper.accessGroup == accessGroup)
    }

    @Test("Access group is nil by default")
    func accessGroupDefaultsToNil() {
        let helper = KeychainHelper(service: testService)
        #expect(helper.accessGroup == nil)
    }

    // MARK: - Sendable Tests

    @Test("KeychainHelper is Sendable")
    func helperIsSendable() async {
        let helper = makeHelper()
        let testKey = "test-sendable-\(UUID().uuidString)"
        defer { cleanup(key: testKey, helper: helper) }

        // Save from main context
        try? helper.save("initial", forKey: testKey)

        // Access from detached task (different concurrency context)
        await Task.detached {
            let retrieved = try? helper.retrieve(forKey: testKey)
            #expect(retrieved == "initial")
        }.value
    }

    @Test("KeychainError is Sendable")
    func errorIsSendable() async {
        let error = KeychainError.itemNotFound

        await Task.detached {
            #expect(error == KeychainError.itemNotFound)
        }.value
    }
}
