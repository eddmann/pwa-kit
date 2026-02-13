import Foundation
@testable import PWAKitApp
import Testing
import UIKit

// MARK: - AppShortcutHandlerTests

@Suite("AppShortcutHandler Tests")
struct AppShortcutHandlerTests {
    // MARK: - Shortcut Type Handling

    @Suite("Shortcut Type Handling")
    struct ShortcutTypeHandlingTests {
        @Test("Can handle configured shortcut types")
        @MainActor
        func canHandleConfiguredTypes() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                    "com.example.settings": "/settings",
                ]
            )

            #expect(handler.canHandle(type: "com.example.dashboard"))
            #expect(handler.canHandle(type: "com.example.settings"))
        }

        @Test("Cannot handle unconfigured shortcut types")
        @MainActor
        func cannotHandleUnconfiguredTypes() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                ]
            )

            #expect(!handler.canHandle(type: "com.example.unknown"))
            #expect(!handler.canHandle(type: "other.shortcut.type"))
        }

        @Test("Empty mappings handle nothing")
        @MainActor
        func emptyMappingsHandleNothing() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            #expect(!handler.canHandle(type: "com.example.anything"))
        }
    }

    // MARK: - URL Generation

    @Suite("URL Generation")
    struct URLGenerationTests {
        @Test("Generates URL from shortcut type")
        @MainActor
        func generatesURLFromType() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                ]
            )

            let url = handler.urlForShortcutType("com.example.dashboard")

            #expect(url?.scheme == "https")
            #expect(url?.host == "app.example.com")
            #expect(url?.path == "/dashboard")
        }

        @Test("Returns nil for unknown shortcut type")
        @MainActor
        func returnsNilForUnknownType() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                ]
            )

            let url = handler.urlForShortcutType("com.example.unknown")

            #expect(url == nil)
        }

        @Test("Handles paths with nested components")
        @MainActor
        func handlesNestedPaths() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.userprofile": "/user/profile",
                    "com.example.appsettings": "/settings/app",
                ]
            )

            let profileURL = handler.urlForShortcutType("com.example.userprofile")
            let settingsURL = handler.urlForShortcutType("com.example.appsettings")

            #expect(profileURL?.path == "/user/profile")
            #expect(settingsURL?.path == "/settings/app")
        }

        @Test("Preserves base URL scheme")
        @MainActor
        func preservesBaseURLScheme() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://secure.example.com")),
                shortcutMappings: [
                    "test": "/test",
                ]
            )

            let url = handler.urlForShortcutType("test")

            #expect(url?.scheme == "https")
            #expect(url?.host == "secure.example.com")
        }
    }

    // MARK: - UIApplicationShortcutItem Handling

    @Suite("UIApplicationShortcutItem Handling")
    struct ShortcutItemHandlingTests {
        @Test("Handles shortcut item with configured mapping")
        @MainActor
        func handlesConfiguredShortcutItem() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                ]
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.dashboard",
                localizedTitle: "Dashboard"
            )

            let url = handler.urlForShortcut(shortcutItem)

            #expect(url?.absoluteString == "https://app.example.com/dashboard")
        }

        @Test("Falls back to userInfo URL")
        @MainActor
        func fallsBackToUserInfoURL() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.custom",
                localizedTitle: "Custom",
                localizedSubtitle: nil,
                icon: nil,
                userInfo: ["url": "https://app.example.com/custom/page" as NSString]
            )

            let url = handler.urlForShortcut(shortcutItem)

            #expect(url?.absoluteString == "https://app.example.com/custom/page")
        }

        @Test("Falls back to userInfo path")
        @MainActor
        func fallsBackToUserInfoPath() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.custom",
                localizedTitle: "Custom",
                localizedSubtitle: nil,
                icon: nil,
                userInfo: ["path": "/custom/path" as NSString]
            )

            let url = handler.urlForShortcut(shortcutItem)

            #expect(url?.path == "/custom/path")
        }

        @Test("Configured mapping takes precedence over userInfo")
        @MainActor
        func configuredMappingTakesPrecedence() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                ]
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.dashboard",
                localizedTitle: "Dashboard",
                localizedSubtitle: nil,
                icon: nil,
                userInfo: ["url": "https://other.com/ignored" as NSString]
            )

            let url = handler.urlForShortcut(shortcutItem)

            #expect(url?.absoluteString == "https://app.example.com/dashboard")
        }

        @Test("Returns nil for unhandled shortcut")
        @MainActor
        func returnsNilForUnhandledShortcut() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.unknown",
                localizedTitle: "Unknown"
            )

            let url = handler.urlForShortcut(shortcutItem)

            #expect(url == nil)
        }

        @Test("handleShortcut sets pending URL")
        @MainActor
        func handleShortcutSetsPendingURL() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "com.example.dashboard": "/dashboard",
                ]
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.dashboard",
                localizedTitle: "Dashboard"
            )

            let handled = handler.handleShortcut(shortcutItem)

            #expect(handled)
            #expect(handler.hasPendingURL)
            #expect(handler.peekPendingURL()?.path == "/dashboard")
        }

        @Test("handleShortcut returns false for unhandled shortcut")
        @MainActor
        func handleShortcutReturnsFalseForUnhandled() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let shortcutItem = UIApplicationShortcutItem(
                type: "com.example.unknown",
                localizedTitle: "Unknown"
            )

            let handled = handler.handleShortcut(shortcutItem)

            #expect(!handled)
            #expect(!handler.hasPendingURL)
        }
    }

    // MARK: - Pending URL Management

    @Suite("Pending URL Management")
    struct PendingURLTests {
        @Test("Setting and consuming pending URL")
        @MainActor
        func setAndConsumePendingURL() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let url = try #require(URL(string: "https://app.example.com/page"))
            handler.setPendingURL(url)

            #expect(handler.hasPendingURL)
            #expect(handler.peekPendingURL() == url)
            #expect(handler.hasPendingURL) // Peek should not consume

            let consumed = handler.consumePendingURL()
            #expect(consumed == url)
            #expect(!handler.hasPendingURL)
            #expect(handler.peekPendingURL() == nil)
        }

        @Test("Consuming returns nil when no pending URL")
        @MainActor
        func consumeReturnsNilWhenEmpty() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            #expect(handler.consumePendingURL() == nil)
            #expect(!handler.hasPendingURL)
        }

        @Test("Setting new URL replaces existing")
        @MainActor
        func settingNewURLReplaces() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let firstURL = try #require(URL(string: "https://app.example.com/first"))
            let secondURL = try #require(URL(string: "https://app.example.com/second"))

            handler.setPendingURL(firstURL)
            handler.setPendingURL(secondURL)

            let consumed = handler.consumePendingURL()
            #expect(consumed == secondURL)
        }

        @Test("Clearing pending URL")
        @MainActor
        func clearPendingURL() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let url = try #require(URL(string: "https://app.example.com/page"))
            handler.setPendingURL(url)

            #expect(handler.hasPendingURL)
            handler.clearPendingURL()
            #expect(!handler.hasPendingURL)
            #expect(handler.consumePendingURL() == nil)
        }

        @Test("Callback invoked when pending URL is set")
        @MainActor
        func callbackInvokedOnSet() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            var callbackURL: URL?
            handler.onPendingURLSet = { url in
                callbackURL = url
            }

            let url = try #require(URL(string: "https://app.example.com/page"))
            handler.setPendingURL(url)

            #expect(callbackURL == url)
        }
    }

    // MARK: - AppConfiguration Integration

    @Suite("AppConfiguration Integration")
    struct AppConfigurationTests {
        @Test("Handler can be created from AppConfiguration")
        @MainActor
        func handlerFromAppConfiguration() {
            let appConfig = AppConfiguration(
                name: "My PWA",
                bundleId: "com.example.mypwa",
                startUrl: "https://app.example.com/start"
            )

            let handler = AppShortcutHandler(
                appConfig: appConfig,
                shortcutMappings: [
                    "test": "/test",
                ]
            )

            #expect(handler != nil)
            #expect(handler?.base.host == "app.example.com")
            #expect(handler?.base.scheme == "https")
        }

        @Test("Returns nil for invalid start URL")
        @MainActor
        func returnsNilForInvalidStartURL() {
            let appConfig = AppConfiguration(
                name: "My PWA",
                bundleId: "com.example.mypwa",
                startUrl: "not-a-valid-url"
            )

            let handler = AppShortcutHandler(appConfig: appConfig)

            #expect(handler == nil)
        }

        @Test("Extracts base URL correctly from start URL")
        @MainActor
        func extractsBaseURLCorrectly() {
            let appConfig = AppConfiguration(
                name: "My PWA",
                bundleId: "com.example.mypwa",
                startUrl: "https://app.example.com/path/to/start?query=value"
            )

            let handler = AppShortcutHandler(appConfig: appConfig)

            // Base URL should be just scheme + host, without path/query
            #expect(handler?.base.absoluteString == "https://app.example.com")
        }
    }

    // MARK: - Properties

    @Suite("Properties")
    struct PropertiesTests {
        @Test("Properties return correct values")
        @MainActor
        func propertiesReturnCorrectValues() throws {
            let baseURL = try #require(URL(string: "https://test.example.com"))
            let mappings = [
                "type1": "/path1",
                "type2": "/path2",
            ]

            let handler = AppShortcutHandler(
                baseURL: baseURL,
                shortcutMappings: mappings
            )

            #expect(handler.base == baseURL)
            #expect(handler.mappings == mappings)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCaseTests {
        @Test("Multiple consume calls return nil after first")
        @MainActor
        func multipleConsumeCallsReturnNil() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com"))
            )

            let url = try #require(URL(string: "https://app.example.com/page"))
            handler.setPendingURL(url)

            _ = handler.consumePendingURL()
            #expect(handler.consumePendingURL() == nil)
            #expect(handler.consumePendingURL() == nil)
        }

        @Test("Handles path without leading slash")
        @MainActor
        func handlesPathWithoutLeadingSlash() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com")),
                shortcutMappings: [
                    "test": "path/without/slash",
                ]
            )

            let url = handler.urlForShortcutType("test")

            #expect(url?.path.contains("path") == true)
        }

        @Test("Handles base URL with trailing slash")
        @MainActor
        func handlesBaseURLWithTrailingSlash() throws {
            let handler = try AppShortcutHandler(
                baseURL: #require(URL(string: "https://app.example.com/")),
                shortcutMappings: [
                    "test": "/dashboard",
                ]
            )

            let url = handler.urlForShortcutType("test")

            #expect(url?.host == "app.example.com")
            #expect(url?.path.contains("dashboard") == true)
        }
    }
}
