import Foundation
@testable import PWAKitApp
import Testing

@Suite("BridgeError Tests")
struct BridgeErrorTests {
    // MARK: - Unknown Module Error

    @Test("Unknown module error has correct description")
    func unknownModuleDescription() {
        let error = BridgeError.unknownModule("widgets")

        #expect(error.localizedDescription == "Unknown module: widgets")
    }

    @Test("Unknown module error includes module name in description")
    func unknownModuleIncludesName() {
        let error = BridgeError.unknownModule("nonexistent")

        #expect(error.localizedDescription.contains("nonexistent"))
    }

    // MARK: - Unknown Action Error

    @Test("Unknown action error has correct description")
    func unknownActionDescription() {
        let error = BridgeError.unknownAction("doSomething")

        #expect(error.localizedDescription == "Unknown action: doSomething")
    }

    @Test("Unknown action error includes action name in description")
    func unknownActionIncludesName() {
        let error = BridgeError.unknownAction("invalidAction")

        #expect(error.localizedDescription.contains("invalidAction"))
    }

    // MARK: - Invalid Payload Error

    @Test("Invalid payload error has correct description")
    func invalidPayloadDescription() {
        let error = BridgeError.invalidPayload("missing required field 'id'")

        #expect(error.localizedDescription == "Invalid payload: missing required field 'id'")
    }

    @Test("Invalid payload error includes reason in description")
    func invalidPayloadIncludesReason() {
        let error = BridgeError.invalidPayload("type mismatch for 'count'")

        #expect(error.localizedDescription.contains("type mismatch for 'count'"))
    }

    // MARK: - Module Error

    @Test("Module error wraps underlying error description")
    func moduleErrorDescription() {
        let underlyingError = NSError(
            domain: "TestDomain",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]
        )
        let error = BridgeError.moduleError(underlying: underlyingError)

        #expect(error.localizedDescription == "Module error: Something went wrong")
    }

    @Test("Module error includes underlying error info")
    func moduleErrorIncludesUnderlying() {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? {
                "Custom failure message"
            }
        }

        let error = BridgeError.moduleError(underlying: CustomError())

        #expect(error.localizedDescription.contains("Custom failure message"))
    }

    // MARK: - Equatable

    @Test("Unknown module errors are equatable")
    func unknownModuleEquatable() {
        let error1 = BridgeError.unknownModule("test")
        let error2 = BridgeError.unknownModule("test")
        let error3 = BridgeError.unknownModule("other")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Unknown action errors are equatable")
    func unknownActionEquatable() {
        let error1 = BridgeError.unknownAction("action")
        let error2 = BridgeError.unknownAction("action")
        let error3 = BridgeError.unknownAction("different")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Invalid payload errors are equatable")
    func invalidPayloadEquatable() {
        let error1 = BridgeError.invalidPayload("reason")
        let error2 = BridgeError.invalidPayload("reason")
        let error3 = BridgeError.invalidPayload("different reason")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Module errors compare by localized description")
    func moduleErrorEquatable() {
        let underlying1 = NSError(
            domain: "Test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Same message"]
        )
        let underlying2 = NSError(
            domain: "Different",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Same message"]
        )
        let underlying3 = NSError(
            domain: "Test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Different message"]
        )

        let error1 = BridgeError.moduleError(underlying: underlying1)
        let error2 = BridgeError.moduleError(underlying: underlying2)
        let error3 = BridgeError.moduleError(underlying: underlying3)

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("Different error types are not equal")
    func differentTypesNotEqual() {
        let unknownModule = BridgeError.unknownModule("test")
        let unknownAction = BridgeError.unknownAction("test")
        let invalidPayload = BridgeError.invalidPayload("test")

        #expect(unknownModule != unknownAction)
        #expect(unknownAction != invalidPayload)
        #expect(unknownModule != invalidPayload)
    }

    // MARK: - CustomStringConvertible

    @Test("Provides debug description for unknown module")
    func debugDescriptionUnknownModule() {
        let error = BridgeError.unknownModule("haptics")

        #expect(error.description == "BridgeError.unknownModule(\"haptics\")")
    }

    @Test("Provides debug description for unknown action")
    func debugDescriptionUnknownAction() {
        let error = BridgeError.unknownAction("trigger")

        #expect(error.description == "BridgeError.unknownAction(\"trigger\")")
    }

    @Test("Provides debug description for invalid payload")
    func debugDescriptionInvalidPayload() {
        let error = BridgeError.invalidPayload("bad format")

        #expect(error.description == "BridgeError.invalidPayload(\"bad format\")")
    }

    @Test("Provides debug description for module error")
    func debugDescriptionModuleError() {
        let underlying = NSError(domain: "Test", code: 1, userInfo: nil)
        let error = BridgeError.moduleError(underlying: underlying)

        #expect(error.description.hasPrefix("BridgeError.moduleError("))
    }

    // MARK: - Error Protocol Conformance

    @Test("Conforms to Error protocol")
    func conformsToError() {
        let error: Error = BridgeError.unknownModule("test")

        #expect(error.localizedDescription == "Unknown module: test")
    }

    @Test("Can be thrown and caught")
    func canBeThrown() throws {
        func throwError() throws {
            throw BridgeError.unknownAction("missing")
        }

        #expect(throws: BridgeError.self) {
            try throwError()
        }
    }

    @Test("Can be caught as specific case")
    func catchSpecificCase() {
        do {
            throw BridgeError.invalidPayload("test reason")
        } catch let BridgeError.invalidPayload(reason) {
            #expect(reason == "test reason")
        } catch {
            Issue.record("Expected BridgeError.invalidPayload")
        }
    }

    // MARK: - Sendable Conformance

    @Test("Is Sendable")
    func isSendable() async {
        let error = BridgeError.unknownModule("test")

        // Verify error can be sent across concurrency boundaries
        await Task {
            let captured = error
            #expect(captured.localizedDescription.contains("test"))
        }.value
    }
}
