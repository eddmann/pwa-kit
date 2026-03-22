import Foundation
@testable import PWAKitApp
import Testing

// MARK: - WidgetModuleTests

@Suite("WidgetModule Tests")
struct WidgetModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(WidgetModule.moduleName == "widget")
    }

    @Test("Supports expected actions")
    func supportsExpectedActions() {
        #expect(WidgetModule.supportedActions == ["update", "remove", "reloadAll", "getKinds"])
        #expect(WidgetModule.supports(action: "update"))
        #expect(WidgetModule.supports(action: "remove"))
        #expect(WidgetModule.supports(action: "reloadAll"))
        #expect(WidgetModule.supports(action: "getKinds"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!WidgetModule.supports(action: "unknown"))
        #expect(!WidgetModule.supports(action: "create"))
        #expect(!WidgetModule.supports(action: ""))
    }

    // MARK: - SharedWidgetData Parsing

    @Test("Parses valid widget data payload")
    func parsesValidPayload() {
        let payload = AnyCodable([
            "kind": AnyCodable("status"),
            "title": AnyCodable("Steps Today"),
            "value": AnyCodable("8,421"),
            "subtitle": AnyCodable("Goal: 10,000"),
            "icon": AnyCodable("figure.walk"),
            "tint": AnyCodable("#34C759"),
            "url": AnyCodable("https://app.example.com/steps"),
        ])

        let data = SharedWidgetData.from(payload: payload)

        #expect(data != nil)
        #expect(data?.kind == "status")
        #expect(data?.title == "Steps Today")
        #expect(data?.value == "8,421")
        #expect(data?.subtitle == "Goal: 10,000")
        #expect(data?.icon == "figure.walk")
        #expect(data?.tint == "#34C759")
        #expect(data?.url == "https://app.example.com/steps")
    }

    @Test("Parses minimal payload with only kind and title")
    func parsesMinimalPayload() {
        let payload = AnyCodable([
            "kind": AnyCodable("compact"),
            "title": AnyCodable("Simple Widget"),
        ])

        let data = SharedWidgetData.from(payload: payload)

        #expect(data != nil)
        #expect(data?.kind == "compact")
        #expect(data?.title == "Simple Widget")
        #expect(data?.value == nil)
        #expect(data?.subtitle == nil)
        #expect(data?.icon == nil)
        #expect(data?.tint == nil)
        #expect(data?.url == nil)
    }

    @Test("Returns nil for missing kind")
    func returnsNilForMissingKind() {
        let payload = AnyCodable([
            "title": AnyCodable("No kind provided"),
        ])

        let data = SharedWidgetData.from(payload: payload)
        #expect(data == nil)
    }

    @Test("Returns nil for missing title")
    func returnsNilForMissingTitle() {
        let payload = AnyCodable([
            "kind": AnyCodable("status"),
        ])

        let data = SharedWidgetData.from(payload: payload)
        #expect(data == nil)
    }

    @Test("Returns nil for nil payload")
    func returnsNilForNilPayload() {
        let data = SharedWidgetData.from(payload: nil)
        #expect(data == nil)
    }

    @Test("Returns nil for empty payload")
    func returnsNilForEmptyPayload() {
        let data = SharedWidgetData.from(payload: AnyCodable([:]))
        #expect(data == nil)
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = WidgetModule()
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
        let module = WidgetModule()
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

    @Test("Update throws for missing kind and title")
    @MainActor
    func updateThrowsForMissingFields() async {
        let module = WidgetModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "update",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("kind") || reason.contains("title"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("Remove throws for missing kind")
    @MainActor
    func removeThrowsForMissingKind() async {
        let module = WidgetModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "remove",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("kind"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - getKinds

    @Test("getKinds returns widget kinds")
    @MainActor
    func getKindsReturnsResult() async throws {
        let module = WidgetModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "getKinds",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["kinds"]?.arrayValue != nil)
        #expect(dict?["kinds"]?.arrayValue?.isEmpty == false)
    }

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = WidgetModule()

        await Task.detached {
            #expect(WidgetModule.moduleName == "widget")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = WidgetModule()

        let _: any PWAModule = module

        #expect(WidgetModule.moduleName == "widget")
        #expect(!WidgetModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = WidgetModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = WidgetModule()

        try module.validateAction("update")
        try module.validateAction("remove")
        try module.validateAction("reloadAll")
        try module.validateAction("getKinds")
    }

    // MARK: - SharedWidgetData Struct

    @Test("SharedWidgetData stores correct properties")
    func widgetDataStoresProperties() {
        let data = SharedWidgetData(
            kind: "status",
            title: "Test Widget",
            value: "42",
            subtitle: "Subtitle",
            icon: "star",
            tint: "#FF0000",
            url: "https://example.com"
        )

        #expect(data.kind == "status")
        #expect(data.title == "Test Widget")
        #expect(data.value == "42")
        #expect(data.subtitle == "Subtitle")
        #expect(data.icon == "star")
        #expect(data.tint == "#FF0000")
        #expect(data.url == "https://example.com")
    }

    @Test("SharedWidgetData is Codable")
    func widgetDataIsCodable() throws {
        let data = SharedWidgetData(
            kind: "compact",
            title: "Codable Test",
            value: "100",
            subtitle: "Encoding"
        )

        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SharedWidgetData.self, from: encoded)

        #expect(decoded == data)
    }

    @Test("SharedWidgetData Equatable works")
    func widgetDataEquatable() {
        let data1 = SharedWidgetData(kind: "status", title: "Same")
        let data2 = SharedWidgetData(kind: "status", title: "Same")
        let data3 = SharedWidgetData(kind: "status", title: "Different")

        #expect(data1 != data2) // updatedAt will differ
        #expect(data1.kind == data2.kind)
        #expect(data1.title == data2.title)
        #expect(data1.title != data3.title)
    }

    @Test("SharedWidgetData has updatedAt timestamp")
    func widgetDataHasTimestamp() {
        let before = Date()
        let data = SharedWidgetData(kind: "test", title: "Timestamp Test")
        let after = Date()

        #expect(data.updatedAt >= before)
        #expect(data.updatedAt <= after)
    }
}
