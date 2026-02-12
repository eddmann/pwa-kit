import Foundation
import Testing

@testable import PWAKitApp

@Suite("BridgeResponse Tests")
struct BridgeResponseTests {
    // MARK: - Success Response Encoding

    @Test("Encodes success response with data")
    func encodesSuccessWithData() throws {
        let response = BridgeResponse.success(
            id: "test-123",
            data: ["triggered": true]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"id\":\"test-123\""))
        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"triggered\":true"))
        #expect(!json.contains("\"error\""))
    }

    @Test("Encodes success response without data")
    func encodesSuccessWithoutData() throws {
        let response = BridgeResponse.success(id: "test-456")

        let data = try JSONEncoder().encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"success\":true"))
        #expect(!json.contains("\"data\""))
        #expect(!json.contains("\"error\""))
    }

    @Test("Decodes success response")
    func decodesSuccessResponse() throws {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "success": true,
          "data": { "triggered": true }
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(response.id == "550e8400-e29b-41d4-a716-446655440000")
        #expect(response.success == true)
        #expect(response.data?["triggered"]?.boolValue == true)
        #expect(response.error == nil)
    }

    // MARK: - Error Response Encoding

    @Test("Encodes error response")
    func encodesErrorResponse() throws {
        let response = BridgeResponse.failure(
            id: "test-789",
            error: "Unknown action: invalid"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"id\":\"test-789\""))
        #expect(json.contains("\"success\":false"))
        #expect(json.contains("\"error\":\"Unknown action: invalid\""))
        #expect(!json.contains("\"data\""))
    }

    @Test("Decodes error response")
    func decodesErrorResponse() throws {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "success": false,
          "error": "Unknown action: invalid"
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(response.id == "550e8400-e29b-41d4-a716-446655440000")
        #expect(response.success == false)
        #expect(response.data == nil)
        #expect(response.error == "Unknown action: invalid")
    }

    // MARK: - Complex Data Types

    @Test("Handles complex nested data")
    func handlesComplexData() throws {
        let response = BridgeResponse.success(
            id: "complex-test",
            data: [
                "platform": "iOS",
                "version": "15.0",
                "features": ["notifications", "haptics", "biometrics"],
                "capabilities": [
                    "push": true,
                    "faceId": true,
                    "touchId": false,
                ],
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let decoded = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(decoded.id == "complex-test")
        #expect(decoded.success == true)
        #expect(decoded.data?["platform"]?.stringValue == "iOS")
        #expect(decoded.data?["version"]?.stringValue == "15.0")
        #expect(decoded.data?["features"]?.arrayValue?.count == 3)
        #expect(decoded.data?["features"]?[0]?.stringValue == "notifications")
        #expect(decoded.data?["capabilities"]?["push"]?.boolValue == true)
        #expect(decoded.data?["capabilities"]?["faceId"]?.boolValue == true)
        #expect(decoded.data?["capabilities"]?["touchId"]?.boolValue == false)
    }

    @Test("Handles numeric data types")
    func handlesNumericData() throws {
        let response = BridgeResponse.success(
            id: "numeric-test",
            data: [
                "intValue": 42,
                "doubleValue": 3.14,
                "array": [1, 2, 3, 4, 5],
            ]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(decoded.data?["intValue"]?.intValue == 42)
        #expect(decoded.data?["doubleValue"]?.doubleValue == 3.14)
        #expect(decoded.data?["array"]?.arrayValue?.count == 5)
    }

    @Test("Handles string data")
    func handlesStringData() throws {
        let response = BridgeResponse.success(
            id: "string-test",
            data: "simple string value"
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(decoded.data?.stringValue == "simple string value")
    }

    @Test("Handles deeply nested data")
    func handlesDeeplyNestedData() throws {
        let json = """
        {
          "id": "nested-test",
          "success": true,
          "data": {
            "level1": {
              "level2": {
                "level3": {
                  "value": "deep"
                }
              }
            }
          }
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: data)

        let value = response.data?["level1"]?["level2"]?["level3"]?["value"]?.stringValue
        #expect(value == "deep")
    }

    // MARK: - Round Trip

    @Test("Round-trips success response")
    func roundTripSuccess() throws {
        let original = BridgeResponse.success(
            id: "round-trip-success",
            data: [
                "users": [
                    ["name": "Alice", "age": 30],
                    ["name": "Bob", "age": 25],
                ],
                "count": 2,
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(decoded == original)
    }

    @Test("Round-trips error response")
    func roundTripError() throws {
        let original = BridgeResponse.failure(
            id: "round-trip-error",
            error: "Something went wrong"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(decoded == original)
    }

    // MARK: - Factory Methods

    @Test("Creates success response via factory method")
    func createsSuccessViaFactory() {
        let response = BridgeResponse.success(id: "factory-success", data: ["key": "value"])

        #expect(response.id == "factory-success")
        #expect(response.success == true)
        #expect(response.data?["key"]?.stringValue == "value")
        #expect(response.error == nil)
    }

    @Test("Creates failure response via factory method")
    func createsFailureViaFactory() {
        let response = BridgeResponse.failure(id: "factory-failure", error: "Test error")

        #expect(response.id == "factory-failure")
        #expect(response.success == false)
        #expect(response.data == nil)
        #expect(response.error == "Test error")
    }

    @Test("Creates success response without data via factory")
    func createsSuccessWithoutDataViaFactory() {
        let response = BridgeResponse.success(id: "no-data")

        #expect(response.id == "no-data")
        #expect(response.success == true)
        #expect(response.data == nil)
        #expect(response.error == nil)
    }

    // MARK: - Direct Initialization

    @Test("Creates response with direct initializer")
    func createsWithDirectInit() {
        let response = BridgeResponse(
            id: "direct-init",
            success: true,
            data: ["status": "ok"],
            error: nil
        )

        #expect(response.id == "direct-init")
        #expect(response.success == true)
        #expect(response.data?["status"]?.stringValue == "ok")
    }

    // MARK: - Equatable

    @Test("Compares equal responses")
    func comparesEqual() {
        let response1 = BridgeResponse.success(id: "equal-test", data: ["key": "value"])
        let response2 = BridgeResponse.success(id: "equal-test", data: ["key": "value"])

        #expect(response1 == response2)
    }

    @Test("Compares unequal responses")
    func comparesUnequal() {
        let response1 = BridgeResponse.success(id: "test-1", data: ["key": "value1"])
        let response2 = BridgeResponse.success(id: "test-1", data: ["key": "value2"])
        let response3 = BridgeResponse.success(id: "test-2", data: ["key": "value1"])
        let response4 = BridgeResponse.failure(id: "test-1", error: "error")

        #expect(response1 != response2)
        #expect(response1 != response3)
        #expect(response1 != response4)
    }

    // MARK: - Description

    @Test("Provides readable description for success")
    func providesSuccessDescription() {
        let response = BridgeResponse.success(id: "desc-test", data: ["key": "value"])
        let description = response.description

        #expect(description.contains("BridgeResponse"))
        #expect(description.contains("desc-test"))
        #expect(description.contains("success: true"))
        #expect(description.contains("data:"))
    }

    @Test("Provides readable description for error")
    func providesErrorDescription() {
        let response = BridgeResponse.failure(id: "err-test", error: "Something failed")
        let description = response.description

        #expect(description.contains("BridgeResponse"))
        #expect(description.contains("err-test"))
        #expect(description.contains("success: false"))
        #expect(description.contains("error: \"Something failed\""))
    }

    // MARK: - Edge Cases

    @Test("Handles empty data object")
    func handlesEmptyData() throws {
        let json = """
        {
          "id": "empty-data",
          "success": true,
          "data": {}
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(response.success == true)
        #expect(response.data?.dictionaryValue?.isEmpty == true)
    }

    @Test("Handles null data field")
    func handlesNullData() throws {
        let json = """
        {
          "id": "null-data",
          "success": true,
          "data": null
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(response.success == true)
        #expect(response.data == nil)
    }

    @Test("Handles empty error string")
    func handlesEmptyError() throws {
        let json = """
        {
          "id": "empty-error",
          "success": false,
          "error": ""
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(response.success == false)
        #expect(response.error == "")
    }

    @Test("Throws on missing required fields")
    func throwsOnMissingFields() {
        let json = """
        {
          "id": "test"
        }
        """

        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BridgeResponse.self, from: data)
        }
    }

    @Test("Throws on invalid JSON")
    func throwsOnInvalidJSON() {
        let json = "not valid json"
        let data = Data(json.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(BridgeResponse.self, from: data)
        }
    }
}
