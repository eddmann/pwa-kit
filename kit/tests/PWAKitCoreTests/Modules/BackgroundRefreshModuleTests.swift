import Foundation
@testable import PWAKitApp
import Testing

// MARK: - BackgroundRefreshModuleTests

@Suite("BackgroundRefreshModule Tests")
struct BackgroundRefreshModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(BackgroundRefreshModule.moduleName == "backgroundRefresh")
    }

    @Test("Supports expected actions")
    func supportsExpectedActions() {
        #expect(BackgroundRefreshModule.supportedActions == [
            "configureUrl", "removeUrl", "getStatus", "scheduleRefresh",
        ])
        #expect(BackgroundRefreshModule.supports(action: "configureUrl"))
        #expect(BackgroundRefreshModule.supports(action: "removeUrl"))
        #expect(BackgroundRefreshModule.supports(action: "getStatus"))
        #expect(BackgroundRefreshModule.supports(action: "scheduleRefresh"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!BackgroundRefreshModule.supports(action: "unknown"))
        #expect(!BackgroundRefreshModule.supports(action: "fetch"))
        #expect(!BackgroundRefreshModule.supports(action: ""))
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = BackgroundRefreshModule()
        let context = ModuleContext()

        await #expect(throws: BridgeError.self) {
            _ = try await module.handle(
                action: "unknownAction",
                payload: nil,
                context: context
            )
        }
    }

    @Test("configureUrl throws for missing url")
    @MainActor
    func configureUrlThrowsForMissingUrl() async {
        let module = BackgroundRefreshModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "configureUrl",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("url"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("configureUrl throws for invalid url")
    @MainActor
    func configureUrlThrowsForInvalidUrl() async {
        let module = BackgroundRefreshModule()
        let context = ModuleContext()

        do {
            _ = try await module.handle(
                action: "configureUrl",
                payload: AnyCodable(["url": AnyCodable("")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("Invalid URL"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - getStatus

    @Test("getStatus returns a result")
    @MainActor
    func getStatusReturnsResult() async throws {
        let module = BackgroundRefreshModule()
        let context = ModuleContext()

        let result = try await module.handle(
            action: "getStatus",
            payload: nil,
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["configured"]?.boolValue != nil)
    }

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = BackgroundRefreshModule()

        await Task.detached {
            #expect(BackgroundRefreshModule.moduleName == "backgroundRefresh")
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = BackgroundRefreshModule()

        let _: any PWAModule = module

        #expect(BackgroundRefreshModule.moduleName == "backgroundRefresh")
        #expect(!BackgroundRefreshModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = BackgroundRefreshModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = BackgroundRefreshModule()

        try module.validateAction("configureUrl")
        try module.validateAction("removeUrl")
        try module.validateAction("getStatus")
        try module.validateAction("scheduleRefresh")
    }
}

// MARK: - BackgroundTaskHandler Parsing Tests

@Suite("BackgroundTaskHandler Parsing Tests")
struct BackgroundTaskHandlerParsingTests {
    @Test("Parses widget data from refresh response")
    func parsesWidgetData() throws {
        let json = """
            {
                "widgets": [
                    {
                        "kind": "status",
                        "title": "Steps Today",
                        "value": "9,200",
                        "subtitle": "Goal: 10,000",
                        "icon": "figure.walk"
                    }
                ]
            }
            """.data(using: .utf8)!

        // Should not throw
        try BackgroundTaskHandler.parseAndStoreRefreshData(json)
    }

    @Test("Parses live activity data from refresh response")
    func parsesActivityData() throws {
        let json = """
            {
                "liveActivity": {
                    "title": "Order #1234",
                    "subtitle": "On the way!",
                    "progress": 0.75
                }
            }
            """.data(using: .utf8)!

        // Should not throw
        try BackgroundTaskHandler.parseAndStoreRefreshData(json)
    }

    @Test("Parses combined widget and activity data")
    func parsesCombinedData() throws {
        let json = """
            {
                "widgets": [
                    { "kind": "status", "title": "Steps", "value": "5,000" },
                    { "kind": "compact", "title": "Weather", "value": "72°F" }
                ],
                "liveActivity": {
                    "title": "Delivery",
                    "subtitle": "5 min away",
                    "progress": 0.9
                }
            }
            """.data(using: .utf8)!

        try BackgroundTaskHandler.parseAndStoreRefreshData(json)
    }

    @Test("Handles empty JSON gracefully")
    func handlesEmptyJson() throws {
        let json = "{}".data(using: .utf8)!

        // Should not throw
        try BackgroundTaskHandler.parseAndStoreRefreshData(json)
    }

    @Test("Skips widgets missing required fields")
    func skipsIncompleteWidgets() throws {
        let json = """
            {
                "widgets": [
                    { "kind": "status" },
                    { "title": "No Kind" },
                    { "kind": "valid", "title": "Valid Widget" }
                ]
            }
            """.data(using: .utf8)!

        // Should not throw — invalid entries are skipped
        try BackgroundTaskHandler.parseAndStoreRefreshData(json)
    }
}

// MARK: - AppGroupStorage Background Refresh Tests

@Suite("AppGroupStorage Background Refresh Tests")
struct AppGroupStorageRefreshTests {
    @Test("Saves and loads refresh URL")
    func savesAndLoadsRefreshUrl() {
        // Configure with a test app group
        AppGroupStorage.configure(appGroupId: "group.com.pwakit.test")

        let testUrl = "https://api.example.com/widget-data"
        AppGroupStorage.saveRefreshUrl(testUrl)

        let loaded = AppGroupStorage.loadRefreshUrl()
        #expect(loaded == testUrl)

        // Clean up
        AppGroupStorage.removeRefreshUrl()
        #expect(AppGroupStorage.loadRefreshUrl() == nil)
    }

    @Test("Records and reads refresh timestamp")
    func recordsRefreshTimestamp() {
        AppGroupStorage.configure(appGroupId: "group.com.pwakit.test")

        // Initially nil
        let initial = AppGroupStorage.lastRefreshTimestamp()
        // May or may not be nil depending on test order, just verify it returns a value type

        AppGroupStorage.recordRefresh()

        let timestamp = AppGroupStorage.lastRefreshTimestamp()
        #expect(timestamp != nil)
        #expect(timestamp! > 0)

        _ = initial // Suppress unused warning
    }
}
