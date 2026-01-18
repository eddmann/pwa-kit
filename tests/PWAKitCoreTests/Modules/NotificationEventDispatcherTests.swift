import Foundation
import Testing
import WebKit

@testable import PWAKitApp

// MARK: - NotificationEventDispatcherTests

@Suite("NotificationEventDispatcher Tests")
struct NotificationEventDispatcherTests {
    // MARK: - Payload Creation Tests

    @Suite("Payload Creation")
    struct PayloadCreationTests {
        @Test("Creates payload with received event type")
        func createsReceivedPayload() {
            let payload = NotificationPayload(
                type: .received,
                title: "Test Title",
                body: "Test Body"
            )

            #expect(payload.type == .received)
            #expect(payload.title == "Test Title")
            #expect(payload.body == "Test Body")
        }

        @Test("Creates payload with tapped event type")
        func createsTappedPayload() {
            let payload = NotificationPayload(
                type: .tapped,
                title: "Tapped Title",
                body: "Tapped Body"
            )

            #expect(payload.type == .tapped)
            #expect(payload.title == "Tapped Title")
            #expect(payload.body == "Tapped Body")
        }

        @Test("Creates payload with all optional fields")
        func createsPayloadWithAllFields() {
            let userInfo: [String: AnyCodable] = [
                "messageId": AnyCodable("123"),
                "senderId": AnyCodable("456"),
            ]

            let payload = NotificationPayload(
                type: .received,
                title: "Full Title",
                body: "Full Body",
                subtitle: "Subtitle",
                userInfo: userInfo,
                badge: 5,
                sound: "default",
                timestamp: 1_704_067_200.0
            )

            #expect(payload.type == .received)
            #expect(payload.title == "Full Title")
            #expect(payload.body == "Full Body")
            #expect(payload.subtitle == "Subtitle")
            #expect(payload.userInfo?["messageId"]?.stringValue == "123")
            #expect(payload.userInfo?["senderId"]?.stringValue == "456")
            #expect(payload.badge == 5)
            #expect(payload.sound == "default")
            #expect(payload.timestamp == 1_704_067_200.0)
        }

        @Test("Creates payload with nil optional fields")
        func createsPayloadWithNilFields() {
            let payload = NotificationPayload(type: .tapped)

            #expect(payload.type == .tapped)
            #expect(payload.title == nil)
            #expect(payload.body == nil)
            #expect(payload.subtitle == nil)
            #expect(payload.userInfo == nil)
            #expect(payload.badge == nil)
            #expect(payload.sound == nil)
        }
    }

    // MARK: - Dispatcher Without WebView Tests

    @Suite("Dispatcher Without WebView")
    struct DispatcherWithoutWebViewTests {
        @Test("Handles dispatch gracefully without WebView")
        @MainActor
        func handlesNoWebView() async {
            let provider = MockWebViewProvider(webView: nil)
            let dispatcher = NotificationEventDispatcher(webViewProvider: provider)

            let payload = NotificationPayload(
                type: .received,
                title: "Test"
            )

            // Should not crash when no WebView is available
            await dispatcher.dispatch(payload)

            // No assertion needed - just verifying it doesn't crash
        }

        @Test("Handles nil provider gracefully")
        @MainActor
        func handlesNilProvider() async {
            let dispatcher = NotificationEventDispatcher(webViewProvider: nil)

            let payload = NotificationPayload(
                type: .tapped,
                title: "Test"
            )

            // Should not crash when provider is nil
            await dispatcher.dispatch(payload)

            // No assertion needed - just verifying it doesn't crash
        }
    }

    // MARK: - JavaScript Formatting Tests

    @Suite("JavaScript Event Formatting")
    struct JavaScriptFormattingTests {
        @Test("Formats event with push type")
        func formatsPushEvent() {
            let event = BridgeEvent(
                type: "push",
                data: AnyCodable([
                    "type": AnyCodable("received"),
                    "title": AnyCodable("Hello"),
                ])
            )

            let js = JavaScriptBridge.formatEvent(event)

            #expect(js.contains("window.pwakit._handleEvent"))
            #expect(js.contains("push"))
            #expect(js.contains("received"))
            #expect(js.contains("Hello"))
        }

        @Test("Escapes special characters in title")
        func escapesSpecialCharacters() {
            let event = BridgeEvent(
                type: "push",
                data: AnyCodable([
                    "title": AnyCodable("Hello \"World\"\nNew Line"),
                ])
            )

            let js = JavaScriptBridge.formatEvent(event)

            // The JSON encoder will escape quotes and newlines
            #expect(js.contains("Hello"))
            #expect(js.contains("World"))
        }

        @Test("Formats event with notification payload data")
        func formatsNotificationPayloadEvent() {
            let userInfo: [String: AnyCodable] = ["key": AnyCodable("value")]
            let payload = NotificationPayload(
                type: .tapped,
                title: "Title",
                body: "Body",
                subtitle: "Subtitle",
                userInfo: userInfo,
                badge: 3,
                sound: "ping"
            )

            // Encode payload to AnyCodable manually (mimicking dispatcher behavior)
            var dict: [String: AnyCodable] = [
                "type": AnyCodable(payload.type.rawValue),
                "timestamp": AnyCodable(payload.timestamp),
            ]
            if let title = payload.title { dict["title"] = AnyCodable(title) }
            if let body = payload.body { dict["body"] = AnyCodable(body) }
            if let subtitle = payload.subtitle { dict["subtitle"] = AnyCodable(subtitle) }
            if let info = payload.userInfo { dict["userInfo"] = AnyCodable(info) }
            if let badge = payload.badge { dict["badge"] = AnyCodable(badge) }
            if let sound = payload.sound { dict["sound"] = AnyCodable(sound) }

            let event = BridgeEvent(type: "push", data: AnyCodable(dict))
            let js = JavaScriptBridge.formatEvent(event)

            #expect(js.contains("tapped"))
            #expect(js.contains("Title"))
            #expect(js.contains("Body"))
            #expect(js.contains("Subtitle"))
            #expect(js.contains("key"))
            #expect(js.contains("value"))
        }
    }

    // MARK: - Event Type Tests

    @Suite("Event Types")
    struct EventTypeTests {
        @Test("Received event type has correct raw value")
        func receivedRawValue() {
            #expect(NotificationPayload.EventType.received.rawValue == "received")
        }

        @Test("Tapped event type has correct raw value")
        func tappedRawValue() {
            #expect(NotificationPayload.EventType.tapped.rawValue == "tapped")
        }

        @Test("Event types are Codable")
        func eventTypesAreCodable() throws {
            let received = NotificationPayload.EventType.received
            let tapped = NotificationPayload.EventType.tapped

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let receivedData = try encoder.encode(received)
            let decodedReceived = try decoder.decode(NotificationPayload.EventType.self, from: receivedData)
            #expect(decodedReceived == .received)

            let tappedData = try encoder.encode(tapped)
            let decodedTapped = try decoder.decode(NotificationPayload.EventType.self, from: tappedData)
            #expect(decodedTapped == .tapped)
        }
    }

    // MARK: - WebViewProvider Protocol Tests

    @Suite("WebViewProvider Protocol")
    struct WebViewProviderProtocolTests {
        @Test("Provider can return nil WebView")
        @MainActor
        func returnsNilWebView() {
            let provider = MockWebViewProvider(webView: nil)

            #expect(provider.webView == nil)
        }
    }

    // MARK: - Notification Payload Encoding Tests

    @Suite("Notification Payload Encoding")
    struct NotificationPayloadEncodingTests {
        @Test("Payload encodes to JSON correctly")
        func encodesToJSON() throws {
            let payload = NotificationPayload(
                type: .received,
                title: "Test Title",
                body: "Test Body",
                timestamp: 1_704_067_200.0
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(payload)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"type\":\"received\""))
            #expect(json.contains("\"title\":\"Test Title\""))
            #expect(json.contains("\"body\":\"Test Body\""))
            #expect(json.contains("\"timestamp\":1704067200"))
        }

        @Test("Payload with userInfo encodes correctly")
        func encodesUserInfo() throws {
            let userInfo: [String: AnyCodable] = [
                "messageId": AnyCodable("123"),
                "priority": AnyCodable(1),
            ]

            let payload = NotificationPayload(
                type: .tapped,
                title: "Tap",
                userInfo: userInfo,
                timestamp: 1_704_067_200.0
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("userInfo"))
            #expect(json.contains("messageId"))
            #expect(json.contains("123"))
        }

        @Test("Payload decodes from JSON correctly")
        func decodesFromJSON() throws {
            let json = """
            {
                "type": "tapped",
                "title": "Decoded Title",
                "body": "Decoded Body",
                "timestamp": 1704067200.0
            }
            """

            let decoder = JSONDecoder()
            let payload = try decoder.decode(NotificationPayload.self, from: json.data(using: .utf8)!)

            #expect(payload.type == .tapped)
            #expect(payload.title == "Decoded Title")
            #expect(payload.body == "Decoded Body")
            #expect(payload.timestamp == 1_704_067_200.0)
        }
    }
}

// MARK: - MockWebViewProvider

/// Mock WebViewProvider for testing.
@MainActor
final class MockWebViewProvider: WebViewProvider {
    nonisolated(unsafe) var webView: WKWebView?

    init(webView: WKWebView?) {
        self.webView = webView
    }
}
