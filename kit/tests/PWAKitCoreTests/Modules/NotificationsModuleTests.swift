import Foundation
import Testing
import UserNotifications

@testable import PWAKitApp

// MARK: - NotificationsModuleTests

@Suite("NotificationsModule Tests")
struct NotificationsModuleTests {
    // MARK: - Permission State Mapping Tests

    @Suite("Permission State Mapping")
    struct PermissionStateMappingTests {
        @Test("Maps notDetermined status correctly")
        func mapsNotDetermined() {
            let module = NotificationsModule()
            let state = module.mapAuthorizationStatus(.notDetermined)
            #expect(state == .notDetermined)
        }

        @Test("Maps denied status correctly")
        func mapsDenied() {
            let module = NotificationsModule()
            let state = module.mapAuthorizationStatus(.denied)
            #expect(state == .denied)
        }

        @Test("Maps authorized status correctly")
        func mapsAuthorized() {
            let module = NotificationsModule()
            let state = module.mapAuthorizationStatus(.authorized)
            #expect(state == .granted)
        }

        @Test("Maps provisional status correctly")
        func mapsProvisional() {
            let module = NotificationsModule()
            let state = module.mapAuthorizationStatus(.provisional)
            #expect(state == .granted)
        }

        @Test("Maps ephemeral status correctly")
        func mapsEphemeral() {
            let module = NotificationsModule()
            let state = module.mapAuthorizationStatus(.ephemeral)
            #expect(state == .granted)
        }
    }

    // MARK: - Token Storage Tests

    @Suite("Token Storage")
    struct TokenStorageTests {
        @Test("UserDefaultsTokenStorage stores and retrieves token")
        func storesAndRetrievesToken() {
            let userDefaults = UserDefaults(suiteName: "test-token-storage")!
            userDefaults.removePersistentDomain(forName: "test-token-storage")

            let storage = UserDefaultsTokenStorage(
                userDefaults: userDefaults,
                key: "test.deviceToken"
            )

            #expect(storage.getToken() == nil)

            storage.setToken("abc123def456")
            #expect(storage.getToken() == "abc123def456")

            storage.setToken("updated-token")
            #expect(storage.getToken() == "updated-token")
        }

        @Test("UserDefaultsTokenStorage clears token")
        func clearsToken() {
            let userDefaults = UserDefaults(suiteName: "test-token-clear")!
            userDefaults.removePersistentDomain(forName: "test-token-clear")

            let storage = UserDefaultsTokenStorage(
                userDefaults: userDefaults,
                key: "test.deviceToken"
            )

            storage.setToken("test-token")
            #expect(storage.getToken() == "test-token")

            storage.clearToken()
            #expect(storage.getToken() == nil)
        }

        @Test("UserDefaultsTokenStorage uses default key")
        func usesDefaultKey() {
            let userDefaults = UserDefaults(suiteName: "test-default-key")!
            userDefaults.removePersistentDomain(forName: "test-default-key")

            let storage = UserDefaultsTokenStorage(userDefaults: userDefaults)

            storage.setToken("test-token")

            let storedValue = userDefaults.string(forKey: NotificationsModule.deviceTokenKey)
            #expect(storedValue == "test-token")
        }
    }

    // MARK: - Get Token Tests

    @Suite("Get Token Action")
    struct GetTokenTests {
        @Test("Returns stored token")
        @MainActor
        func returnsStoredToken() async throws {
            let storage = MockTokenStorage(token: "stored-device-token")
            let module = NotificationsModule(
                storage: storage,
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "getToken",
                payload: nil,
                context: context
            )

            #expect(result?["token"]?.stringValue == "stored-device-token")
        }

        @Test("Returns null when no token stored")
        @MainActor
        func returnsNullWhenNoToken() async throws {
            let storage = MockTokenStorage(token: nil)
            let module = NotificationsModule(
                storage: storage,
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "getToken",
                payload: nil,
                context: context
            )

            #expect(result?["token"]?.isNull == true)
        }
    }

    // MARK: - Get Permission State Tests

    @Suite("Get Permission State Action")
    struct GetPermissionStateTests {
        @Test("Returns granted state")
        @MainActor
        func returnsGrantedState() async throws {
            let notificationCenter = MockNotificationCenter(authorizationStatus: .authorized)
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "getPermissionState",
                payload: nil,
                context: context
            )

            #expect(result?["state"]?.stringValue == "granted")
        }

        @Test("Returns denied state")
        @MainActor
        func returnsDeniedState() async throws {
            let notificationCenter = MockNotificationCenter(authorizationStatus: .denied)
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "getPermissionState",
                payload: nil,
                context: context
            )

            #expect(result?["state"]?.stringValue == "denied")
        }

        @Test("Returns not_determined state")
        @MainActor
        func returnsNotDeterminedState() async throws {
            let notificationCenter = MockNotificationCenter(authorizationStatus: .notDetermined)
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "getPermissionState",
                payload: nil,
                context: context
            )

            #expect(result?["state"]?.stringValue == "not_determined")
        }
    }

    // MARK: - Set Badge Tests

    @Suite("Set Badge Action")
    struct SetBadgeTests {
        @Test("Sets badge count successfully")
        @MainActor
        func setsBadgeSuccessfully() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable(["count": AnyCodable(5)])

            let result = try await module.handle(
                action: "setBadge",
                payload: payload,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
        }

        @Test("Sets badge to zero")
        @MainActor
        func setsBadgeToZero() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable(["count": AnyCodable(0)])

            let result = try await module.handle(
                action: "setBadge",
                payload: payload,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
        }

        @Test("Throws error for missing count")
        @MainActor
        func throwsForMissingCount() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([:] as [String: AnyCodable])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "setBadge",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for negative count")
        @MainActor
        func throwsForNegativeCount() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable(["count": AnyCodable(-1)])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "setBadge",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for invalid count type")
        @MainActor
        func throwsForInvalidCountType() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable(["count": AnyCodable("not-a-number")])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "setBadge",
                    payload: payload,
                    context: context
                )
            }
        }
    }

    // MARK: - Subscribe Tests

    @Suite("Subscribe Action")
    struct SubscribeTests {
        @Test("Returns success when permission granted with existing token")
        @MainActor
        func successWithExistingToken() async throws {
            let storage = MockTokenStorage(token: "existing-token")
            let notificationCenter = MockNotificationCenter(
                authorizationStatus: .authorized,
                willGrantAuthorization: true
            )
            let module = NotificationsModule(
                storage: storage,
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "subscribe",
                payload: nil,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(result?["token"]?.stringValue == "existing-token")
            #expect(result?["permissionState"]?.stringValue == "granted")
        }

        @Test("Returns success without token when permission granted but no token stored")
        @MainActor
        func successWithoutToken() async throws {
            let storage = MockTokenStorage(token: nil)
            let notificationCenter = MockNotificationCenter(
                authorizationStatus: .authorized,
                willGrantAuthorization: true
            )
            let module = NotificationsModule(
                storage: storage,
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "subscribe",
                payload: nil,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(result?["token"] == nil)
            #expect(result?["permissionState"]?.stringValue == "granted")
        }

        @Test("Returns failure when permission denied")
        @MainActor
        func failureWhenDenied() async throws {
            let storage = MockTokenStorage(token: nil)
            let notificationCenter = MockNotificationCenter(
                authorizationStatus: .denied,
                willGrantAuthorization: false
            )
            let module = NotificationsModule(
                storage: storage,
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "subscribe",
                payload: nil,
                context: context
            )

            #expect(result?["success"]?.boolValue == false)
            #expect(result?["token"] == nil)
            #expect(result?["permissionState"]?.stringValue == "denied")
            #expect(result?["error"]?.stringValue?.contains("denied") == true)
        }
    }

    // MARK: - Unknown Action Tests

    @Suite("Unknown Action")
    struct UnknownActionTests {
        @Test("Throws error for unknown action")
        @MainActor
        func throwsForUnknownAction() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "unknownAction",
                    payload: nil,
                    context: context
                )
            }
        }
    }

    // MARK: - Schedule Tests

    @Suite("Schedule Action")
    struct ScheduleTests {
        @Test("Schedules time interval notification successfully")
        @MainActor
        func schedulesTimeIntervalNotification() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("test-notification"),
                "title": AnyCodable("Test Title"),
                "body": AnyCodable("Test Body"),
                "trigger": AnyCodable([
                    "type": AnyCodable("timeInterval"),
                    "seconds": AnyCodable(60),
                ]),
            ])

            let result = try await module.handle(
                action: "schedule",
                payload: payload,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(result?["id"]?.stringValue == "test-notification")
            #expect(notificationCenter.addedRequestCount == 1)
            #expect(notificationCenter.lastAddedRequest?.identifier == "test-notification")
            #expect(notificationCenter.lastAddedRequest?.content.title == "Test Title")
            #expect(notificationCenter.lastAddedRequest?.content.body == "Test Body")
        }

        @Test("Schedules calendar notification successfully")
        @MainActor
        func schedulesCalendarNotification() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("daily-reminder"),
                "title": AnyCodable("Daily Reminder"),
                "trigger": AnyCodable([
                    "type": AnyCodable("calendar"),
                    "hour": AnyCodable(9),
                    "minute": AnyCodable(0),
                    "repeats": AnyCodable(true),
                ]),
            ])

            let result = try await module.handle(
                action: "schedule",
                payload: payload,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(notificationCenter.addedRequestCount == 1)
            let trigger = notificationCenter.lastAddedRequest?.trigger as? UNCalendarNotificationTrigger
            #expect(trigger?.repeats == true)
        }

        @Test("Schedules date notification successfully")
        @MainActor
        func schedulesDateNotification() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            // Create a future date
            let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
            let dateString = ISO8601DateFormatter().string(from: futureDate)

            let payload = AnyCodable([
                "id": AnyCodable("meeting-reminder"),
                "title": AnyCodable("Meeting starts"),
                "trigger": AnyCodable([
                    "type": AnyCodable("date"),
                    "date": AnyCodable(dateString),
                ]),
            ])

            let result = try await module.handle(
                action: "schedule",
                payload: payload,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(notificationCenter.addedRequestCount == 1)
            let trigger = notificationCenter.lastAddedRequest?.trigger as? UNCalendarNotificationTrigger
            #expect(trigger?.repeats == false)
        }

        @Test("Sets notification sound correctly")
        @MainActor
        func setsNotificationSound() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("sound-test"),
                "title": AnyCodable("Sound Test"),
                "sound": AnyCodable("default"),
                "trigger": AnyCodable([
                    "type": AnyCodable("timeInterval"),
                    "seconds": AnyCodable(60),
                ]),
            ])

            _ = try await module.handle(
                action: "schedule",
                payload: payload,
                context: context
            )

            #expect(notificationCenter.lastAddedRequest?.content.sound != nil)
        }

        @Test("Sets badge correctly")
        @MainActor
        func setsBadge() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("badge-test"),
                "title": AnyCodable("Badge Test"),
                "badge": AnyCodable(5),
                "trigger": AnyCodable([
                    "type": AnyCodable("timeInterval"),
                    "seconds": AnyCodable(60),
                ]),
            ])

            _ = try await module.handle(
                action: "schedule",
                payload: payload,
                context: context
            )

            #expect(notificationCenter.lastAddedRequest?.content.badge == 5)
        }

        @Test("Throws error for missing id")
        @MainActor
        func throwsForMissingId() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "title": AnyCodable("Test"),
                "trigger": AnyCodable(["type": AnyCodable("timeInterval"), "seconds": AnyCodable(60)]),
            ])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "schedule",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for missing title")
        @MainActor
        func throwsForMissingTitle() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("test"),
                "trigger": AnyCodable(["type": AnyCodable("timeInterval"), "seconds": AnyCodable(60)]),
            ])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "schedule",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for missing trigger")
        @MainActor
        func throwsForMissingTrigger() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("test"),
                "title": AnyCodable("Test"),
            ])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "schedule",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for repeating interval less than 60 seconds")
        @MainActor
        func throwsForShortRepeatingInterval() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("test"),
                "title": AnyCodable("Test"),
                "trigger": AnyCodable([
                    "type": AnyCodable("timeInterval"),
                    "seconds": AnyCodable(30),
                    "repeats": AnyCodable(true),
                ]),
            ])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "schedule",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for past date")
        @MainActor
        func throwsForPastDate() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
            let dateString = ISO8601DateFormatter().string(from: pastDate)
            let payload = AnyCodable([
                "id": AnyCodable("test"),
                "title": AnyCodable("Test"),
                "trigger": AnyCodable([
                    "type": AnyCodable("date"),
                    "date": AnyCodable(dateString),
                ]),
            ])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "schedule",
                    payload: payload,
                    context: context
                )
            }
        }

        @Test("Throws error for invalid calendar hour")
        @MainActor
        func throwsForInvalidCalendarHour() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([
                "id": AnyCodable("test"),
                "title": AnyCodable("Test"),
                "trigger": AnyCodable([
                    "type": AnyCodable("calendar"),
                    "hour": AnyCodable(25),
                ]),
            ])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "schedule",
                    payload: payload,
                    context: context
                )
            }
        }
    }

    // MARK: - Cancel Tests

    @Suite("Cancel Action")
    struct CancelTests {
        @Test("Cancels notification successfully")
        @MainActor
        func cancelsNotificationSuccessfully() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()
            let payload = AnyCodable(["id": AnyCodable("test-notification")])

            let result = try await module.handle(
                action: "cancel",
                payload: payload,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(notificationCenter.lastRemovedIdentifiers.contains("test-notification"))
        }

        @Test("Throws error for missing id")
        @MainActor
        func throwsForMissingId() async throws {
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: MockNotificationCenter()
            )
            let context = ModuleContext()
            let payload = AnyCodable([:] as [String: AnyCodable])

            await #expect(throws: BridgeError.self) {
                _ = try await module.handle(
                    action: "cancel",
                    payload: payload,
                    context: context
                )
            }
        }
    }

    // MARK: - Cancel All Tests

    @Suite("Cancel All Action")
    struct CancelAllTests {
        @Test("Cancels all notifications successfully")
        @MainActor
        func cancelsAllNotificationsSuccessfully() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "cancelAll",
                payload: nil,
                context: context
            )

            #expect(result?["success"]?.boolValue == true)
            #expect(notificationCenter.wasAllRemoved == true)
        }
    }

    // MARK: - Get Pending Tests

    @Suite("Get Pending Action")
    struct GetPendingTests {
        @Test("Returns empty array when no pending notifications")
        @MainActor
        func returnsEmptyArrayWhenNoPending() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            let result = try await module.handle(
                action: "getPending",
                payload: nil,
                context: context
            )

            let notifications = result?["notifications"]?.arrayValue
            #expect(notifications != nil)
            #expect(notifications?.isEmpty == true)
        }

        @Test("Returns pending notifications")
        @MainActor
        func returnsPendingNotifications() async throws {
            let notificationCenter = MockNotificationCenter()
            let module = NotificationsModule(
                storage: MockTokenStorage(),
                notificationCenter: notificationCenter
            )
            let context = ModuleContext()

            // Schedule a notification first
            let schedulePayload = AnyCodable([
                "id": AnyCodable("test-pending"),
                "title": AnyCodable("Pending Test"),
                "body": AnyCodable("Test body"),
                "trigger": AnyCodable([
                    "type": AnyCodable("timeInterval"),
                    "seconds": AnyCodable(3600),
                ]),
            ])

            _ = try await module.handle(
                action: "schedule",
                payload: schedulePayload,
                context: context
            )

            // Now get pending
            let result = try await module.handle(
                action: "getPending",
                payload: nil,
                context: context
            )

            let notifications = result?["notifications"]?.arrayValue
            #expect(notifications?.count == 1)

            let first = notifications?.first?.dictionaryValue
            #expect(first?["id"]?.stringValue == "test-pending")
            #expect(first?["title"]?.stringValue == "Pending Test")
            #expect(first?["body"]?.stringValue == "Test body")
        }
    }

    // MARK: - Module Configuration Tests

    @Suite("Module Configuration")
    struct ModuleConfigurationTests {
        @Test("Has correct module name")
        func hasCorrectModuleName() {
            #expect(NotificationsModule.moduleName == "notifications")
        }

        @Test("Has all expected supported actions")
        func hasExpectedSupportedActions() {
            let actions = NotificationsModule.supportedActions
            #expect(actions.contains("subscribe"))
            #expect(actions.contains("getToken"))
            #expect(actions.contains("getPermissionState"))
            #expect(actions.contains("setBadge"))
            #expect(actions.contains("schedule"))
            #expect(actions.contains("cancel"))
            #expect(actions.contains("cancelAll"))
            #expect(actions.contains("getPending"))
            #expect(actions.count == 8)
        }

        @Test("Uses correct device token key")
        func usesCorrectDeviceTokenKey() {
            #expect(NotificationsModule.deviceTokenKey == "PWAKit.deviceToken")
        }
    }

    // MARK: - Data Extension Tests

    @Suite("Data hexEncodedString")
    struct DataHexEncodedStringTests {
        @Test("Encodes empty data")
        func encodesEmptyData() {
            let data = Data()
            #expect(data.hexEncodedString() == "")
        }

        @Test("Encodes single byte")
        func encodesSingleByte() {
            let data = Data([0xFF])
            #expect(data.hexEncodedString() == "ff")
        }

        @Test("Encodes multiple bytes")
        func encodesMultipleBytes() {
            let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
            #expect(data.hexEncodedString() == "deadbeef")
        }

        @Test("Encodes with leading zeros")
        func encodesWithLeadingZeros() {
            let data = Data([0x00, 0x01, 0x02])
            #expect(data.hexEncodedString() == "000102")
        }

        @Test("Encodes typical device token")
        func encodesTypicalDeviceToken() {
            // Simulate a typical 32-byte device token
            let data = Data([
                0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
                0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00,
                0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
            ])
            let expected = "112233445566778899aabbccddeeff00001122334455667788" +
                "99aabbccddeeff"
            #expect(data.hexEncodedString() == expected)
        }
    }
}

// MARK: - MockTokenStorage

/// Mock token storage for testing.
final class MockTokenStorage: TokenStorage, @unchecked Sendable {
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func getToken() -> String? {
        token
    }

    func setToken(_ token: String) {
        self.token = token
    }

    func clearToken() {
        token = nil
    }
}

// MARK: - MockNotificationCenter

/// Mock notification center for testing.
final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private let authorizationStatus: UNAuthorizationStatus
    private let willGrantAuthorization: Bool
    private var addedRequests: [UNNotificationRequest] = []
    private var removedIdentifiers: [String] = []
    private var allRemoved = false

    init(
        authorizationStatus: UNAuthorizationStatus = .notDetermined,
        willGrantAuthorization: Bool = false
    ) {
        self.authorizationStatus = authorizationStatus
        self.willGrantAuthorization = willGrantAuthorization
    }

    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool {
        willGrantAuthorization
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        addedRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        allRemoved = true
        addedRequests.removeAll()
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        addedRequests
    }

    /// Test helpers
    var lastAddedRequest: UNNotificationRequest? {
        addedRequests.last
    }

    var addedRequestCount: Int {
        addedRequests.count
    }

    var lastRemovedIdentifiers: [String] {
        removedIdentifiers
    }

    var wasAllRemoved: Bool {
        allRemoved
    }
}
