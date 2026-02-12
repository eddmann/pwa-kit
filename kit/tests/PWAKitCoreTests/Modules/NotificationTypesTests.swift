import Foundation
import Testing

@testable import PWAKitApp

@Suite("NotificationTypes Tests")
struct NotificationTypesTests {
    // MARK: - NotificationPermissionState Tests

    @Suite("NotificationPermissionState")
    struct PermissionStateTests {
        @Test("Encodes to expected JSON string values")
        func encodesToExpectedValues() throws {
            let encoder = JSONEncoder()

            let notDetermined = try encoder.encode(NotificationPermissionState.notDetermined)
            #expect(String(data: notDetermined, encoding: .utf8) == "\"not_determined\"")

            let denied = try encoder.encode(NotificationPermissionState.denied)
            #expect(String(data: denied, encoding: .utf8) == "\"denied\"")

            let granted = try encoder.encode(NotificationPermissionState.granted)
            #expect(String(data: granted, encoding: .utf8) == "\"granted\"")

            let unavailable = try encoder.encode(NotificationPermissionState.unavailable)
            #expect(String(data: unavailable, encoding: .utf8) == "\"unavailable\"")

            let unknown = try encoder.encode(NotificationPermissionState.unknown)
            #expect(String(data: unknown, encoding: .utf8) == "\"unknown\"")
        }

        @Test("Decodes from JSON string values")
        func decodesFromJSONStrings() throws {
            let decoder = JSONDecoder()

            let notDetermined = try decoder.decode(
                NotificationPermissionState.self,
                from: "\"not_determined\"".data(using: .utf8)!
            )
            #expect(notDetermined == .notDetermined)

            let denied = try decoder.decode(
                NotificationPermissionState.self,
                from: "\"denied\"".data(using: .utf8)!
            )
            #expect(denied == .denied)

            let granted = try decoder.decode(
                NotificationPermissionState.self,
                from: "\"granted\"".data(using: .utf8)!
            )
            #expect(granted == .granted)

            let unavailable = try decoder.decode(
                NotificationPermissionState.self,
                from: "\"unavailable\"".data(using: .utf8)!
            )
            #expect(unavailable == .unavailable)

            let unknown = try decoder.decode(
                NotificationPermissionState.self,
                from: "\"unknown\"".data(using: .utf8)!
            )
            #expect(unknown == .unknown)
        }

        @Test("Throws error for invalid value")
        func throwsForInvalidValue() {
            let decoder = JSONDecoder()

            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(
                    NotificationPermissionState.self,
                    from: "\"invalid\"".data(using: .utf8)!
                )
            }
        }

        @Test("Is Sendable")
        func isSendable() async {
            let state = NotificationPermissionState.granted

            await Task.detached {
                #expect(state == .granted)
            }.value
        }

        @Test("All cases are defined")
        func allCasesAreDefined() {
            let allCases = NotificationPermissionState.allCases
            #expect(allCases.count == 5)
            #expect(allCases.contains(.notDetermined))
            #expect(allCases.contains(.denied))
            #expect(allCases.contains(.granted))
            #expect(allCases.contains(.unavailable))
            #expect(allCases.contains(.unknown))
        }
    }

    // MARK: - NotificationSubscription Tests

    @Suite("NotificationSubscription")
    struct SubscriptionTests {
        @Test("Successful subscription encodes correctly")
        func successfulSubscriptionEncodes() throws {
            let subscription = NotificationSubscription(
                token: "abc123def456",
                permissionState: .granted
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(subscription)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":true"))
            #expect(json.contains("\"token\":\"abc123def456\""))
            #expect(json.contains("\"permissionState\":\"granted\""))
            // Note: nil values are omitted by default JSONEncoder
            #expect(!json.contains("\"error\"") || json.contains("\"error\":null"))
        }

        @Test("Failed subscription encodes correctly")
        func failedSubscriptionEncodes() throws {
            let subscription = NotificationSubscription(
                error: "User denied permission",
                permissionState: .denied
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(subscription)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":false"))
            // Note: nil values are omitted by default JSONEncoder
            #expect(!json.contains("\"token\"") || json.contains("\"token\":null"))
            #expect(json.contains("\"permissionState\":\"denied\""))
            #expect(json.contains("\"error\":\"User denied permission\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "success": true,
                "token": "device-token-123",
                "permissionState": "granted",
                "error": null
            }
            """

            let decoder = JSONDecoder()
            let subscription = try decoder.decode(
                NotificationSubscription.self,
                from: json.data(using: .utf8)!
            )

            #expect(subscription.success == true)
            #expect(subscription.token == "device-token-123")
            #expect(subscription.permissionState == .granted)
            #expect(subscription.error == nil)
        }

        @Test("Decodes failed subscription from JSON")
        func decodesFailedSubscriptionFromJSON() throws {
            let json = """
            {
                "success": false,
                "token": null,
                "permissionState": "not_determined",
                "error": "Registration failed"
            }
            """

            let decoder = JSONDecoder()
            let subscription = try decoder.decode(
                NotificationSubscription.self,
                from: json.data(using: .utf8)!
            )

            #expect(subscription.success == false)
            #expect(subscription.token == nil)
            #expect(subscription.permissionState == .notDetermined)
            #expect(subscription.error == "Registration failed")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = NotificationSubscription(
                token: "test-token",
                permissionState: .granted
            )

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(NotificationSubscription.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let subscription = NotificationSubscription(
                token: "test-token",
                permissionState: .granted
            )

            await Task.detached {
                #expect(subscription.success == true)
            }.value
        }

        @Test("Convenience initializer for success sets correct values")
        func successInitializerSetsCorrectValues() {
            let subscription = NotificationSubscription(
                token: "my-token",
                permissionState: .granted
            )

            #expect(subscription.success == true)
            #expect(subscription.token == "my-token")
            #expect(subscription.permissionState == .granted)
            #expect(subscription.error == nil)
        }

        @Test("Convenience initializer for failure sets correct values")
        func failureInitializerSetsCorrectValues() {
            let subscription = NotificationSubscription(
                error: "Something went wrong",
                permissionState: .unavailable
            )

            #expect(subscription.success == false)
            #expect(subscription.token == nil)
            #expect(subscription.permissionState == .unavailable)
            #expect(subscription.error == "Something went wrong")
        }
    }

    // MARK: - NotificationPayload Tests

    @Suite("NotificationPayload")
    struct PayloadTests {
        @Test("Encodes with all fields")
        func encodesWithAllFields() throws {
            let payload = NotificationPayload(
                type: .tapped,
                title: "Test Title",
                body: "Test body message",
                subtitle: "Test Subtitle",
                userInfo: [
                    "messageId": AnyCodable("123"),
                    "priority": AnyCodable(1),
                ],
                badge: 5,
                sound: "default",
                timestamp: 1_704_067_200.0
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(payload)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"type\":\"tapped\""))
            #expect(json.contains("\"title\":\"Test Title\""))
            #expect(json.contains("\"body\":\"Test body message\""))
            #expect(json.contains("\"subtitle\":\"Test Subtitle\""))
            #expect(json.contains("\"badge\":5"))
            #expect(json.contains("\"sound\":\"default\""))
            #expect(json.contains("\"timestamp\":1704067200"))
            #expect(json.contains("\"messageId\":\"123\""))
            #expect(json.contains("\"priority\":1"))
        }

        @Test("Encodes with minimal fields")
        func encodesWithMinimalFields() throws {
            let payload = NotificationPayload(
                type: .received,
                timestamp: 1_704_067_200.0
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"type\":\"received\""))
            #expect(json.contains("\"timestamp\":1704067200"))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "type": "tapped",
                "title": "Hello",
                "body": "World",
                "subtitle": null,
                "userInfo": {"key": "value"},
                "badge": 3,
                "sound": "ping",
                "timestamp": 1704067200.5
            }
            """

            let decoder = JSONDecoder()
            let payload = try decoder.decode(
                NotificationPayload.self,
                from: json.data(using: .utf8)!
            )

            #expect(payload.type == .tapped)
            #expect(payload.title == "Hello")
            #expect(payload.body == "World")
            #expect(payload.subtitle == nil)
            #expect(payload.userInfo?["key"]?.stringValue == "value")
            #expect(payload.badge == 3)
            #expect(payload.sound == "ping")
            #expect(payload.timestamp == 1_704_067_200.5)
        }

        @Test("Decodes received event type")
        func decodesReceivedEventType() throws {
            let json = """
            {
                "type": "received",
                "title": null,
                "body": null,
                "subtitle": null,
                "userInfo": null,
                "badge": null,
                "sound": null,
                "timestamp": 1704067200.0
            }
            """

            let decoder = JSONDecoder()
            let payload = try decoder.decode(
                NotificationPayload.self,
                from: json.data(using: .utf8)!
            )

            #expect(payload.type == .received)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = NotificationPayload(
                type: .tapped,
                title: "Notification",
                body: "You have a new message",
                subtitle: "From: Alice",
                userInfo: ["id": AnyCodable("msg-123")],
                badge: 1,
                sound: "default",
                timestamp: 1_704_067_200.0
            )

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(NotificationPayload.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let payload = NotificationPayload(
                type: .received,
                title: "Test",
                timestamp: 1_704_067_200.0
            )

            await Task.detached {
                #expect(payload.type == .received)
            }.value
        }

        @Test("EventType encodes correctly")
        func eventTypeEncodes() throws {
            let encoder = JSONEncoder()

            let received = try encoder.encode(NotificationPayload.EventType.received)
            #expect(String(data: received, encoding: .utf8) == "\"received\"")

            let tapped = try encoder.encode(NotificationPayload.EventType.tapped)
            #expect(String(data: tapped, encoding: .utf8) == "\"tapped\"")
        }

        @Test("EventType decodes correctly")
        func eventTypeDecodes() throws {
            let decoder = JSONDecoder()

            let received = try decoder.decode(
                NotificationPayload.EventType.self,
                from: "\"received\"".data(using: .utf8)!
            )
            #expect(received == .received)

            let tapped = try decoder.decode(
                NotificationPayload.EventType.self,
                from: "\"tapped\"".data(using: .utf8)!
            )
            #expect(tapped == .tapped)
        }

        @Test("Default timestamp is set")
        func defaultTimestampIsSet() {
            let before = Date().timeIntervalSince1970
            let payload = NotificationPayload(type: .received)
            let after = Date().timeIntervalSince1970

            #expect(payload.timestamp >= before)
            #expect(payload.timestamp <= after)
        }
    }

    // MARK: - SetBadgeRequest Tests

    @Suite("SetBadgeRequest")
    struct SetBadgeRequestTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let request = SetBadgeRequest(count: 42)

            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json == "{\"count\":42}")
        }

        @Test("Encodes zero badge")
        func encodesZeroBadge() throws {
            let request = SetBadgeRequest(count: 0)

            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json == "{\"count\":0}")
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = "{\"count\":10}"

            let decoder = JSONDecoder()
            let request = try decoder.decode(
                SetBadgeRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.count == 10)
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = SetBadgeRequest(count: 99)

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SetBadgeRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = SetBadgeRequest(count: 5)

            await Task.detached {
                #expect(request.count == 5)
            }.value
        }
    }
}
