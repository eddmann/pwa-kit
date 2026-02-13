import Foundation
@testable import PWAKitApp
import Testing

// MARK: - BridgeMessageTests

@Suite("BridgeMessage Tests")
struct BridgeMessageTests {
    // MARK: - Basic Encoding/Decoding

    @Test("Decodes message with all fields")
    func decodesCompleteMessage() throws {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "module": "haptics",
          "action": "impact",
          "payload": { "style": "medium" }
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(message.id == "550e8400-e29b-41d4-a716-446655440000")
        #expect(message.module == "haptics")
        #expect(message.action == "impact")
        #expect(message.payload?["style"]?.stringValue == "medium")
    }

    @Test("Decodes message without payload")
    func decodesMessageWithoutPayload() throws {
        let json = """
        {
          "id": "abc-123",
          "module": "platform",
          "action": "getInfo"
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(message.id == "abc-123")
        #expect(message.module == "platform")
        #expect(message.action == "getInfo")
        #expect(message.payload == nil)
    }

    @Test("Decodes message with null payload")
    func decodesMessageWithNullPayload() throws {
        let json = """
        {
          "id": "test-id",
          "module": "test",
          "action": "test",
          "payload": null
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        // JSON null with decodeIfPresent results in nil (field absent)
        // This is standard Swift Codable behavior
        #expect(message.payload == nil)
    }

    @Test("Encodes message to JSON")
    func encodesMessage() throws {
        let message = BridgeMessage(
            id: "test-123",
            module: "haptics",
            action: "impact",
            payload: ["style": "heavy"]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(message)
        let decoded = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(decoded == message)
    }

    @Test("Encodes message without payload")
    func encodesMessageWithoutPayload() throws {
        let message = BridgeMessage(
            id: "test-456",
            module: "platform",
            action: "getInfo"
        )

        let data = try JSONEncoder().encode(message)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("payload"))
    }

    // MARK: - Various Payload Types

    @Test("Handles string payload")
    func handlesStringPayload() throws {
        let json = """
        {
          "id": "1",
          "module": "test",
          "action": "test",
          "payload": "simple string"
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(message.payload?.stringValue == "simple string")
    }

    @Test("Handles number payload")
    func handlesNumberPayload() throws {
        let json = """
        {
          "id": "1",
          "module": "test",
          "action": "test",
          "payload": 42
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(message.payload?.intValue == 42)
    }

    @Test("Handles boolean payload")
    func handlesBooleanPayload() throws {
        let json = """
        {
          "id": "1",
          "module": "test",
          "action": "test",
          "payload": true
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(message.payload?.boolValue == true)
    }

    @Test("Handles array payload")
    func handlesArrayPayload() throws {
        let json = """
        {
          "id": "1",
          "module": "test",
          "action": "test",
          "payload": ["one", "two", "three"]
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        let array = message.payload?.arrayValue
        #expect(array?.count == 3)
        #expect(array?[0].stringValue == "one")
        #expect(array?[2].stringValue == "three")
    }

    @Test("Handles nested object payload")
    func handlesNestedPayload() throws {
        let json = """
        {
          "id": "1",
          "module": "test",
          "action": "test",
          "payload": {
            "outer": {
              "inner": {
                "value": 123
              }
            }
          }
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        let value = message.payload?["outer"]?["inner"]?["value"]?.intValue
        #expect(value == 123)
    }

    @Test("Handles complex mixed payload")
    func handlesComplexPayload() throws {
        let json = """
        {
          "id": "1",
          "module": "test",
          "action": "test",
          "payload": {
            "string": "hello",
            "number": 42,
            "decimal": 3.14,
            "boolean": true,
            "null": null,
            "array": [1, 2, 3],
            "nested": { "key": "value" }
          }
        }
        """

        let data = Data(json.utf8)
        let message = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(message.payload?["string"]?.stringValue == "hello")
        #expect(message.payload?["number"]?.intValue == 42)
        #expect(message.payload?["decimal"]?.doubleValue == 3.14)
        #expect(message.payload?["boolean"]?.boolValue == true)
        #expect(message.payload?["null"]?.isNull == true)
        #expect(message.payload?["array"]?.arrayValue?.count == 3)
        #expect(message.payload?["nested"]?["key"]?.stringValue == "value")
    }

    // MARK: - Round Trip

    @Test("Round-trips through JSON encoding")
    func roundTripEncoding() throws {
        let original = BridgeMessage(
            id: "round-trip-test",
            module: "notifications",
            action: "subscribe",
            payload: [
                "topics": ["news", "alerts"],
                "options": [
                    "sound": true,
                    "badge": true,
                ],
            ]
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BridgeMessage.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Initialization

    @Test("Creates message with auto-generated UUID")
    func createsWithAutoUUID() {
        let message = BridgeMessage(
            module: "haptics",
            action: "impact",
            payload: ["style": "light"]
        )

        #expect(!message.id.isEmpty)
        #expect(message.module == "haptics")
        #expect(message.action == "impact")
    }

    @Test("Creates message with explicit ID")
    func createsWithExplicitID() {
        let message = BridgeMessage(
            id: "custom-id",
            module: "platform",
            action: "getInfo"
        )

        #expect(message.id == "custom-id")
        #expect(message.payload == nil)
    }

    // MARK: - Error Cases

    @Test("Throws on missing required fields")
    func throwsOnMissingFields() {
        let json = """
        {
          "id": "test",
          "module": "test"
        }
        """

        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BridgeMessage.self, from: data)
        }
    }

    @Test("Throws on invalid JSON")
    func throwsOnInvalidJSON() {
        let json = "not valid json"
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BridgeMessage.self, from: data)
        }
    }
}

// MARK: - AnyCodableTests

@Suite("AnyCodable Tests")
struct AnyCodableTests {
    // MARK: - Basic Types

    @Test("Encodes and decodes null")
    func encodesNull() throws {
        let value: AnyCodable = nil
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded.isNull)
    }

    @Test("Encodes and decodes boolean")
    func encodesBoolean() throws {
        let value: AnyCodable = true
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded.boolValue == true)
    }

    @Test("Encodes and decodes integer")
    func encodesInteger() throws {
        let value: AnyCodable = 42
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded.intValue == 42)
    }

    @Test("Encodes and decodes double")
    func encodesDouble() throws {
        let value: AnyCodable = 3.14
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded.doubleValue == 3.14)
    }

    @Test("Encodes and decodes string")
    func encodesString() throws {
        let value: AnyCodable = "hello"
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded.stringValue == "hello")
    }

    @Test("Encodes and decodes array")
    func encodesArray() throws {
        let value: AnyCodable = [1, 2, 3]
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let array = decoded.arrayValue
        #expect(array?.count == 3)
        #expect(array?[0].intValue == 1)
        #expect(array?[2].intValue == 3)
    }

    @Test("Encodes and decodes dictionary")
    func encodesDictionary() throws {
        let value: AnyCodable = ["key": "value", "number": 123]
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded["key"]?.stringValue == "value")
        #expect(decoded["number"]?.intValue == 123)
    }

    // MARK: - Type Conversions

    @Test("Double to int conversion for whole numbers")
    func doubleToIntConversion() throws {
        let json = "42.0"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        // JSON decoder may decode as double
        #expect(decoded.intValue == 42)
        #expect(decoded.doubleValue == 42.0)
    }

    @Test("Int to double conversion")
    func intToDoubleConversion() {
        let value: AnyCodable = 42
        #expect(value.doubleValue == 42.0)
    }

    // MARK: - Subscript Access

    @Test("Subscript returns nil for wrong type")
    func subscriptWrongType() {
        let value: AnyCodable = "string"

        #expect(value["key"] == nil)
        #expect(value[0] == nil)
    }

    @Test("Subscript returns nil for out of bounds")
    func subscriptOutOfBounds() {
        let value: AnyCodable = [1, 2, 3]

        #expect(value[5] == nil)
        #expect(value[-1] == nil)
    }

    // MARK: - Literal Initialization

    @Test("Initializes from nil literal")
    func initFromNilLiteral() {
        let value: AnyCodable = nil
        #expect(value.isNull)
    }

    @Test("Initializes from boolean literal")
    func initFromBoolLiteral() {
        let value: AnyCodable = false
        #expect(value.boolValue == false)
    }

    @Test("Initializes from integer literal")
    func initFromIntLiteral() {
        let value: AnyCodable = 100
        #expect(value.intValue == 100)
    }

    @Test("Initializes from float literal")
    func initFromFloatLiteral() {
        let value: AnyCodable = 2.718
        #expect(value.doubleValue == 2.718)
    }

    @Test("Initializes from string literal")
    func initFromStringLiteral() {
        let value: AnyCodable = "test"
        #expect(value.stringValue == "test")
    }

    @Test("Initializes from array literal")
    func initFromArrayLiteral() {
        let value: AnyCodable = ["a", "b", "c"]
        #expect(value.arrayValue?.count == 3)
    }

    @Test("Initializes from dictionary literal")
    func initFromDictionaryLiteral() {
        let value: AnyCodable = ["x": 1, "y": 2]
        #expect(value["x"]?.intValue == 1)
        #expect(value["y"]?.intValue == 2)
    }

    // MARK: - Equatable

    @Test("Compares equal values")
    func comparesEqual() {
        #expect(AnyCodable(42) == AnyCodable(42))
        #expect(AnyCodable("test") == AnyCodable("test"))
        #expect(AnyCodable(true) == AnyCodable(true))
        #expect(AnyCodable.null == AnyCodable.null)
    }

    @Test("Compares unequal values")
    func comparesUnequal() {
        #expect(AnyCodable(42) != AnyCodable(43))
        #expect(AnyCodable("test") != AnyCodable("other"))
        #expect(AnyCodable(true) != AnyCodable(false))
        #expect(AnyCodable(1) != AnyCodable("1"))
    }

    // MARK: - Description

    @Test("Provides readable description")
    func providesDescription() {
        #expect(AnyCodable.null.description == "null")
        #expect(AnyCodable(true).description == "true")
        #expect(AnyCodable(42).description == "42")
        #expect(AnyCodable("hello").description == "\"hello\"")
    }

    // MARK: - Value Access

    @Test("Returns nil for mismatched type access")
    func returnNilForMismatch() {
        let stringValue: AnyCodable = "test"

        #expect(stringValue.boolValue == nil)
        #expect(stringValue.intValue == nil)
        #expect(stringValue.doubleValue == nil)
        #expect(stringValue.arrayValue == nil)
        #expect(stringValue.dictionaryValue == nil)
    }

    @Test("Returns Any value")
    func returnsAnyValue() {
        let value: AnyCodable = ["key": "value"]
        let any = value.value as? [String: Any?]

        #expect(any?["key"] as? String == "value")
    }
}
