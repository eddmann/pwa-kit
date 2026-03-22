import Foundation
@testable import PWAKitApp
import Testing

// MARK: - LiveActivityModuleTests

@available(iOS 16.1, *)
@Suite("LiveActivityModule Tests")
struct LiveActivityModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(LiveActivityModule.moduleName == "liveActivity")
    }

    @Test("Supports expected actions")
    func supportsExpectedActions() {
        #expect(LiveActivityModule.supportedActions == [
            "start", "update", "end", "getState", "areActivitiesEnabled", "getPushToken",
        ])
        #expect(LiveActivityModule.supports(action: "start"))
        #expect(LiveActivityModule.supports(action: "update"))
        #expect(LiveActivityModule.supports(action: "end"))
        #expect(LiveActivityModule.supports(action: "getState"))
        #expect(LiveActivityModule.supports(action: "areActivitiesEnabled"))
        #expect(LiveActivityModule.supports(action: "getPushToken"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!LiveActivityModule.supports(action: "unknown"))
        #expect(!LiveActivityModule.supports(action: "pause"))
        #expect(!LiveActivityModule.supports(action: ""))
    }

    // MARK: - SharedActivityData Parsing

    @Test("Parses valid activity data payload")
    func parsesValidPayload() {
        let payload = AnyCodable([
            "title": AnyCodable("Order #1234"),
            "subtitle": AnyCodable("Preparing your food"),
            "progress": AnyCodable(0.45),
            "icon": AnyCodable("fork.knife"),
            "tint": AnyCodable("#FF6B35"),
        ])

        let data = SharedActivityData.from(payload: payload)

        #expect(data != nil)
        #expect(data?.title == "Order #1234")
        #expect(data?.subtitle == "Preparing your food")
        #expect(data?.progress == 0.45)
        #expect(data?.icon == "fork.knife")
        #expect(data?.tint == "#FF6B35")
    }

    @Test("Parses payload with fields")
    func parsesPayloadWithFields() {
        let payload = AnyCodable([
            "title": AnyCodable("Delivery"),
            "fields": AnyCodable([
                "eta": AnyCodable("12:30 PM"),
                "status": AnyCodable("Cooking"),
            ]),
        ])

        let data = SharedActivityData.from(payload: payload)

        #expect(data != nil)
        #expect(data?.fields?["eta"] == "12:30 PM")
        #expect(data?.fields?["status"] == "Cooking")
    }

    @Test("Parses minimal payload with only title")
    func parsesMinimalPayload() {
        let payload = AnyCodable([
            "title": AnyCodable("Simple Activity"),
        ])

        let data = SharedActivityData.from(payload: payload)

        #expect(data != nil)
        #expect(data?.title == "Simple Activity")
        #expect(data?.subtitle == nil)
        #expect(data?.progress == nil)
        #expect(data?.icon == nil)
        #expect(data?.tint == nil)
        #expect(data?.fields == nil)
    }

    @Test("Returns nil for missing title")
    func returnsNilForMissingTitle() {
        let payload = AnyCodable([
            "subtitle": AnyCodable("No title provided"),
        ])

        let data = SharedActivityData.from(payload: payload)
        #expect(data == nil)
    }

    @Test("Returns nil for nil payload")
    func returnsNilForNilPayload() {
        let data = SharedActivityData.from(payload: nil)
        #expect(data == nil)
    }

    @Test("Returns nil for empty payload")
    func returnsNilForEmptyPayload() {
        let data = SharedActivityData.from(payload: AnyCodable([:]))
        #expect(data == nil)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = LiveActivityModule()
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
        let module = LiveActivityModule()
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

    @Test("Start throws for missing title")
    @MainActor
    func startThrowsForMissingTitle() async {
        let module = LiveActivityModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "start",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("title"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("Update throws for missing title")
    @MainActor
    func updateThrowsForMissingTitle() async {
        let module = LiveActivityModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "update",
                payload: AnyCodable([:]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("title"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - areActivitiesEnabled

    @Test("areActivitiesEnabled returns a result")
    @MainActor
    func areActivitiesEnabledReturnsResult() async throws {
        let module = LiveActivityModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "areActivitiesEnabled",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["enabled"]?.boolValue != nil)
    }

    // MARK: - getState

    @Test("getState returns activity state")
    @MainActor
    func getStateReturnsState() async throws {
        let module = LiveActivityModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "getState",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["active"]?.boolValue != nil)
        #expect(dict?["count"]?.intValue != nil)
    }

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = LiveActivityModule()

        await Task.detached {
            #expect(LiveActivityModule.moduleName == "liveActivity")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = LiveActivityModule()

        let _: any PWAModule = module

        #expect(LiveActivityModule.moduleName == "liveActivity")
        #expect(!LiveActivityModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = LiveActivityModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = LiveActivityModule()

        try module.validateAction("start")
        try module.validateAction("update")
        try module.validateAction("end")
        try module.validateAction("getState")
        try module.validateAction("areActivitiesEnabled")
        try module.validateAction("getPushToken")
    }

    // MARK: - SharedActivityData Struct

    @Test("SharedActivityData stores correct properties")
    func activityDataStoresProperties() {
        let data = SharedActivityData(
            title: "Test Activity",
            subtitle: "Test Subtitle",
            progress: 0.5,
            icon: "star",
            tint: "#FF0000",
            fields: ["key": "value"]
        )

        #expect(data.title == "Test Activity")
        #expect(data.subtitle == "Test Subtitle")
        #expect(data.progress == 0.5)
        #expect(data.icon == "star")
        #expect(data.tint == "#FF0000")
        #expect(data.fields?["key"] == "value")
    }

    @Test("SharedActivityData is Codable")
    func activityDataIsCodable() throws {
        let data = SharedActivityData(
            title: "Codable Test",
            subtitle: "Encoding",
            progress: 0.75,
            icon: "checkmark",
            tint: "#00FF00"
        )

        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SharedActivityData.self, from: encoded)

        #expect(decoded == data)
    }

    @Test("SharedActivityData Equatable works")
    func activityDataEquatable() {
        let data1 = SharedActivityData(title: "Same", subtitle: "Data")
        let data2 = SharedActivityData(title: "Same", subtitle: "Data")
        let data3 = SharedActivityData(title: "Different", subtitle: "Data")

        #expect(data1 == data2)
        #expect(data1 != data3)
    }

    // MARK: - getPushToken

    @Test("getPushToken returns a result")
    @MainActor
    func getPushTokenReturnsResult() async throws {
        let module = LiveActivityModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "getPushToken",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        // Token key should always be present (may be null)
        #expect(dict?["token"] != nil)
    }
}
