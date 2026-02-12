import Foundation
import Testing

@testable import PWAKitApp

// MARK: - IAPModuleTests

@Suite("IAPModule Tests")
struct IAPModuleTests {
    // MARK: - Module Properties

    @Test("Has correct module name")
    func hasCorrectModuleName() {
        #expect(IAPModule.moduleName == "iap")
    }

    @Test("Supports expected actions")
    func supportsExpectedActions() {
        #expect(IAPModule.supportedActions == ["getProducts", "purchase", "restore", "getEntitlements"])
        #expect(IAPModule.supports(action: "getProducts"))
        #expect(IAPModule.supports(action: "purchase"))
        #expect(IAPModule.supports(action: "restore"))
        #expect(IAPModule.supports(action: "getEntitlements"))
    }

    @Test("Does not support unknown actions")
    func doesNotSupportUnknownActions() {
        #expect(!IAPModule.supports(action: "unknown"))
        #expect(!IAPModule.supports(action: "subscribe"))
        #expect(!IAPModule.supports(action: "buy"))
        #expect(!IAPModule.supports(action: ""))
    }

    // MARK: - Get Products Action

    @Test("getProducts throws for missing productIds")
    @MainActor
    func getProductsThrowsForMissingProductIds() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Test with nil payload
        do {
            _ = try await module.handle(
                action: "getProducts",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("productIds"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("getProducts throws for empty productIds array")
    @MainActor
    func getProductsThrowsForEmptyProductIds() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Test with empty productIds
        do {
            _ = try await module.handle(
                action: "getProducts",
                payload: AnyCodable(["productIds": AnyCodable([AnyCodable]())]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("productIds"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("getProducts throws for non-array productIds")
    @MainActor
    func getProductsThrowsForNonArrayProductIds() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Test with string instead of array
        do {
            _ = try await module.handle(
                action: "getProducts",
                payload: AnyCodable(["productIds": AnyCodable("com.example.product")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("productIds"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    // MARK: - Purchase Action

    @Test("purchase throws for missing productId")
    @MainActor
    func purchaseThrowsForMissingProductId() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Test with nil payload
        do {
            _ = try await module.handle(
                action: "purchase",
                payload: nil,
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("productId"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("purchase throws for empty payload")
    @MainActor
    func purchaseThrowsForEmptyPayload() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Test with empty payload (no productId field)
        do {
            _ = try await module.handle(
                action: "purchase",
                payload: AnyCodable(["other": AnyCodable("value")]),
                context: context
            )
            Issue.record("Expected error to be thrown")
        } catch let error as BridgeError {
            if case let .invalidPayload(reason) = error {
                #expect(reason.contains("productId"))
            } else {
                Issue.record("Expected invalidPayload error, got \(error)")
            }
        } catch {
            Issue.record("Expected BridgeError, got \(error)")
        }
    }

    @Test("purchase returns failure for non-existent product")
    @MainActor
    func purchaseReturnsFailureForNonExistentProduct() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Attempt to purchase a product that hasn't been fetched
        let result = try await module.handle(
            action: "purchase",
            payload: AnyCodable(["productId": AnyCodable("com.nonexistent.product")]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)
        #expect(dict?["success"]?.boolValue == false)
        #expect(dict?["productId"]?.stringValue == "com.nonexistent.product")
        #expect(dict?["error"]?.stringValue != nil)
    }

    // MARK: - Restore Action
    // Note: Tests for restore and getEntitlements that call actual StoreKit APIs
    // are excluded to avoid test hangs. These operations include:
    // - restore (requires AppStore.sync)
    // - getEntitlements (iterates Transaction.currentEntitlements)
    //
    // To fully test these actions, configure a StoreKit Testing configuration
    // file and run tests in Xcode with the configuration enabled.

    @Test("restore is a supported action")
    func restoreIsSupported() {
        #expect(IAPModule.supports(action: "restore"))
    }

    // MARK: - Get Entitlements Action

    @Test("getEntitlements is a supported action")
    func getEntitlementsIsSupported() {
        #expect(IAPModule.supports(action: "getEntitlements"))
    }

    // MARK: - Error Handling

    @Test("Throws error for unknown action")
    @MainActor
    func throwsForUnknownAction() async throws {
        let module = IAPModule()
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
        let module = IAPModule()
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

    // MARK: - Sendable Conformance

    @Test("Module is Sendable")
    func moduleIsSendable() async {
        let module = IAPModule()

        // Verify module can be safely used across concurrency boundaries
        await Task.detached {
            _ = module
        }.value
    }

    // MARK: - PWAModule Protocol

    @Test("Conforms to PWAModule protocol")
    func conformsToPWAModule() {
        let module = IAPModule()

        // Verify protocol conformance by using as PWAModule
        let _: any PWAModule = module

        // Verify static properties
        #expect(IAPModule.moduleName == "iap")
        #expect(!IAPModule.supportedActions.isEmpty)
    }

    @Test("validateAction throws for unsupported action")
    func validateActionThrows() throws {
        let module = IAPModule()

        #expect(throws: BridgeError.self) {
            try module.validateAction("unsupported")
        }
    }

    @Test("validateAction succeeds for supported actions")
    func validateActionSucceeds() throws {
        let module = IAPModule()

        try module.validateAction("getProducts")
        try module.validateAction("purchase")
        try module.validateAction("restore")
        try module.validateAction("getEntitlements")
        // Should not throw
    }

    // MARK: - Response Format Tests

    @Test("purchase failure result has expected fields")
    @MainActor
    func purchaseFailureHasExpectedFields() async throws {
        let module = IAPModule()
        let context = ModuleContext()

        // Purchase a non-existent product to get a failure
        let result = try await module.handle(
            action: "purchase",
            payload: AnyCodable(["productId": AnyCodable("com.test.invalid")]),
            context: context
        )

        let dict = result?.dictionaryValue
        #expect(dict != nil)

        // Must have success, productId, and error fields
        #expect(dict?["success"] != nil)
        #expect(dict?["productId"]?.stringValue == "com.test.invalid")
        #expect(dict?["success"]?.boolValue == false)
        #expect(dict?["error"]?.stringValue != nil)
    }
}

// MARK: - IAPModuleIntegrationTests

@Suite("IAPModule Integration Tests")
struct IAPModuleIntegrationTests {
    // Note: These tests would require StoreKit Testing configuration files
    // to work properly. They are structured to show how integration testing
    // would be done with actual StoreKit operations.

    @Test("Module can be initialized with default manager")
    func initWithDefaultManager() {
        let module = IAPModule()
        #expect(IAPModule.moduleName == "iap")
        _ = module
    }

    @Test("Module can be initialized with custom manager")
    func initWithCustomManager() {
        let manager = StoreKitManager()
        let module = IAPModule(storeKitManager: manager)
        #expect(IAPModule.moduleName == "iap")
        _ = module
    }
}
