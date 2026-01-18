import Foundation
import Testing

@testable import PWAKitApp

@Suite("JavaScriptBridge Tests")
struct JavaScriptBridgeTests {
    // MARK: - Callback Generation

    @Test("Generates callback for success response")
    func generatesCallbackForSuccess() {
        let response = BridgeResponse.success(
            id: "test-123",
            data: ["status": "ok"]
        )

        let js = JavaScriptBridge.formatCallback(response)

        #expect(js.hasPrefix("window.pwakit._handleResponse("))
        #expect(js.hasSuffix(");"))
        #expect(js.contains("\"id\":\"test-123\""))
        #expect(js.contains("\"success\":true"))
    }

    @Test("Generates callback for error response")
    func generatesCallbackForError() {
        let response = BridgeResponse.failure(
            id: "error-456",
            error: "Something went wrong"
        )

        let js = JavaScriptBridge.formatCallback(response)

        #expect(js.hasPrefix("window.pwakit._handleResponse("))
        #expect(js.hasSuffix(");"))
        #expect(js.contains("\"id\":\"error-456\""))
        #expect(js.contains("\"success\":false"))
        #expect(js.contains("\"error\":\"Something went wrong\""))
    }

    @Test("Generates callback from JSON string")
    func generatesCallbackFromJSON() {
        let json = "{\"id\":\"json-test\",\"success\":true}"

        let js = JavaScriptBridge.formatCallback(jsonString: json)

        #expect(js == "window.pwakit._handleResponse({\"id\":\"json-test\",\"success\":true});")
    }

    @Test("Generates callback with complex data")
    func generatesCallbackWithComplexData() {
        let response = BridgeResponse.success(
            id: "complex-test",
            data: [
                "platform": "iOS",
                "features": ["haptics", "push"],
                "config": ["enabled": true],
            ]
        )

        let js = JavaScriptBridge.formatCallback(response)

        #expect(js.hasPrefix("window.pwakit._handleResponse("))
        #expect(js.contains("\"platform\":\"iOS\""))
        #expect(js.contains("\"features\""))
        #expect(js.contains("\"config\""))
    }

    // MARK: - Event Dispatch Generation

    @Test("Generates event dispatch")
    func generatesEventDispatch() {
        let event = BridgeEvent(
            type: "push",
            data: ["title": "New Message", "body": "Hello world"]
        )

        let js = JavaScriptBridge.formatEvent(event)

        #expect(js.hasPrefix("window.pwakit._handleEvent("))
        #expect(js.hasSuffix(");"))
        #expect(js.contains("\"type\":\"push\""))
        #expect(js.contains("\"title\":\"New Message\""))
    }

    @Test("Generates event dispatch with convenience method")
    func generatesEventWithConvenienceMethod() {
        let js = JavaScriptBridge.formatEvent(
            type: "lifecycle",
            data: ["state": "foreground"]
        )

        #expect(js.hasPrefix("window.pwakit._handleEvent("))
        #expect(js.contains("\"type\":\"lifecycle\""))
        #expect(js.contains("\"state\":\"foreground\""))
    }

    @Test("Generates event without data")
    func generatesEventWithoutData() {
        let event = BridgeEvent(type: "ready", data: nil)

        let js = JavaScriptBridge.formatEvent(event)

        #expect(js.hasPrefix("window.pwakit._handleEvent("))
        #expect(js.contains("\"type\":\"ready\""))
        #expect(!js.contains("\"data\":"))
    }

    // MARK: - Escaping of Special Characters

    @Test("Escapes double quotes")
    func escapesDoubleQuotes() {
        let input = "Hello \"World\""
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "Hello \\\"World\\\"")
    }

    @Test("Escapes backslashes")
    func escapesBackslashes() {
        let input = "path\\to\\file"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "path\\\\to\\\\file")
    }

    @Test("Escapes newlines")
    func escapesNewlines() {
        let input = "line1\nline2"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "line1\\nline2")
    }

    @Test("Escapes carriage returns")
    func escapesCarriageReturns() {
        let input = "line1\rline2"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "line1\\rline2")
    }

    @Test("Escapes tabs")
    func escapesTabs() {
        let input = "col1\tcol2"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "col1\\tcol2")
    }

    @Test("Escapes line separator U+2028")
    func escapesLineSeparator() {
        let input = "line1\u{2028}line2"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "line1\\u2028line2")
    }

    @Test("Escapes paragraph separator U+2029")
    func escapesParagraphSeparator() {
        let input = "para1\u{2029}para2"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "para1\\u2029para2")
    }

    @Test("Escapes multiple special characters")
    func escapesMultipleSpecialChars() {
        let input = "Say \"Hello\\World\"\nNew line"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == "Say \\\"Hello\\\\World\\\"\\nNew line")
    }

    @Test("Handles empty string")
    func handlesEmptyString() {
        let escaped = JavaScriptBridge.escapeForJavaScript("")

        #expect(escaped == "")
    }

    @Test("Preserves normal characters")
    func preservesNormalCharacters() {
        let input = "Hello World 123 !@#$%"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == input)
    }

    @Test("Preserves unicode characters")
    func preservesUnicodeCharacters() {
        let input = "Hello \u{1F600} World"
        let escaped = JavaScriptBridge.escapeForJavaScript(input)

        #expect(escaped == input)
    }

    // MARK: - JSON Encoding

    @Test("Encodes response to compact JSON")
    func encodesResponseToCompactJSON() {
        let response = BridgeResponse.success(id: "test", data: ["key": "value"])
        let json = JavaScriptBridge.encodeToJSON(response)

        // Compact JSON should not have unnecessary whitespace
        #expect(!json.contains("\n"))
        #expect(!json.contains("  "))
    }

    @Test("Returns empty object on encoding failure")
    func returnsEmptyOnEncodingFailure() {
        struct NonEncodable: Encodable {
            func encode(to _: Encoder) throws {
                throw NSError(domain: "test", code: 1, userInfo: nil)
            }
        }

        let json = JavaScriptBridge.encodeToJSON(NonEncodable())

        #expect(json == "{}")
    }

    // MARK: - BridgeEvent

    @Test("Creates event with type and data")
    func createsEventWithTypeAndData() {
        let event = BridgeEvent(
            type: "push",
            data: ["title": "Test", "body": "Message"]
        )

        #expect(event.type == "push")
        #expect(event.data?["title"]?.stringValue == "Test")
        #expect(event.data?["body"]?.stringValue == "Message")
    }

    @Test("Creates event without data")
    func createsEventWithoutData() {
        let event = BridgeEvent(type: "ready", data: nil)

        #expect(event.type == "ready")
        #expect(event.data == nil)
    }

    @Test("Encodes event to JSON")
    func encodesEventToJSON() throws {
        let event = BridgeEvent(
            type: "lifecycle",
            data: ["state": "background"]
        )

        let data = try JSONEncoder().encode(event)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"type\":\"lifecycle\""))
        #expect(json.contains("\"state\":\"background\""))
    }

    @Test("Decodes event from JSON")
    func decodesEventFromJSON() throws {
        let json = """
        {
          "type": "deeplink",
          "data": { "url": "myapp://page/123" }
        }
        """

        let data = Data(json.utf8)
        let event = try JSONDecoder().decode(BridgeEvent.self, from: data)

        #expect(event.type == "deeplink")
        #expect(event.data?["url"]?.stringValue == "myapp://page/123")
    }

    @Test("Round-trips event through JSON")
    func roundTripsEvent() throws {
        let original = BridgeEvent(
            type: "notification",
            data: [
                "title": "Alert",
                "badge": 5,
                "userInfo": ["key": "value"],
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BridgeEvent.self, from: data)

        #expect(decoded == original)
    }

    @Test("Compares equal events")
    func comparesEqualEvents() {
        let event1 = BridgeEvent(type: "test", data: ["key": "value"])
        let event2 = BridgeEvent(type: "test", data: ["key": "value"])

        #expect(event1 == event2)
    }

    @Test("Compares unequal events")
    func comparesUnequalEvents() {
        let event1 = BridgeEvent(type: "type1", data: ["key": "value"])
        let event2 = BridgeEvent(type: "type2", data: ["key": "value"])
        let event3 = BridgeEvent(type: "type1", data: ["different": "data"])

        #expect(event1 != event2)
        #expect(event1 != event3)
    }

    @Test("Provides readable event description")
    func providesEventDescription() {
        let event = BridgeEvent(type: "push", data: ["title": "Test"])
        let description = event.description

        #expect(description.contains("BridgeEvent"))
        #expect(description.contains("type: push"))
        #expect(description.contains("data:"))
    }

    // MARK: - Generated JavaScript Validity

    @Test("Generated callback is valid JavaScript function call")
    func callbackIsValidJavaScript() {
        let response = BridgeResponse.success(id: "valid-test", data: ["key": "value"])
        let js = JavaScriptBridge.formatCallback(response)

        // Valid JavaScript pattern: functionCall(arg);
        #expect(js.hasPrefix("window.pwakit._handleResponse("))
        #expect(js.hasSuffix(");"))

        // Ensure JSON inside parentheses is parseable
        let jsonStart = js.index(js.startIndex, offsetBy: "window.pwakit._handleResponse(".count)
        let jsonEnd = js.index(js.endIndex, offsetBy: -2) // Remove ");"
        let jsonString = String(js[jsonStart ..< jsonEnd])

        // Verify it's valid JSON
        let jsonData = jsonString.data(using: .utf8)!
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: jsonData)
        }
    }

    @Test("Generated event dispatch is valid JavaScript function call")
    func eventDispatchIsValidJavaScript() {
        let event = BridgeEvent(type: "test", data: ["value": 123])
        let js = JavaScriptBridge.formatEvent(event)

        // Valid JavaScript pattern: functionCall(arg);
        #expect(js.hasPrefix("window.pwakit._handleEvent("))
        #expect(js.hasSuffix(");"))

        // Ensure JSON inside parentheses is parseable
        let jsonStart = js.index(js.startIndex, offsetBy: "window.pwakit._handleEvent(".count)
        let jsonEnd = js.index(js.endIndex, offsetBy: -2) // Remove ");"
        let jsonString = String(js[jsonStart ..< jsonEnd])

        // Verify it's valid JSON
        let jsonData = jsonString.data(using: .utf8)!
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: jsonData)
        }
    }

    @Test("Handles response with special characters in error message")
    func handlesSpecialCharsInError() throws {
        let response = BridgeResponse.failure(
            id: "special-test",
            error: "Error: \"value\" contains\nnewline"
        )

        let js = JavaScriptBridge.formatCallback(response)

        // The JavaScript should still be valid
        #expect(js.hasPrefix("window.pwakit._handleResponse("))
        #expect(js.hasSuffix(");"))

        // Extract and parse JSON
        let jsonStart = js.index(js.startIndex, offsetBy: "window.pwakit._handleResponse(".count)
        let jsonEnd = js.index(js.endIndex, offsetBy: -2)
        let jsonString = String(js[jsonStart ..< jsonEnd])

        let jsonData = jsonString.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        #expect(parsed["id"] as? String == "special-test")
        #expect(parsed["success"] as? Bool == false)
        // The error should contain the special characters (properly encoded in JSON)
        let error = parsed["error"] as? String
        #expect(error?.contains("\"value\"") == true)
        #expect(error?.contains("\n") == true)
    }

    @Test("Handles event with complex nested data")
    func handlesEventWithNestedData() throws {
        let event = BridgeEvent(
            type: "notification",
            data: [
                "aps": [
                    "alert": [
                        "title": "Hello",
                        "body": "World",
                    ],
                    "badge": 1,
                ],
                "customKey": "customValue",
            ]
        )

        let js = JavaScriptBridge.formatEvent(event)

        // Extract and parse JSON
        let jsonStart = js.index(js.startIndex, offsetBy: "window.pwakit._handleEvent(".count)
        let jsonEnd = js.index(js.endIndex, offsetBy: -2)
        let jsonString = String(js[jsonStart ..< jsonEnd])

        let jsonData = jsonString.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        #expect(parsed["type"] as? String == "notification")
        let data = parsed["data"] as? [String: Any]
        #expect(data != nil)
        #expect(data?["customKey"] as? String == "customValue")
    }
}
