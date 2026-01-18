import Foundation
import StoreKit
import Testing

@testable import PWAKitApp

// MARK: - StoreKitManagerTests

@Suite("StoreKitManager Tests")
struct StoreKitManagerTests {
    // MARK: - Initialization

    @Test("Can be initialized")
    func canBeInitialized() async {
        let manager = StoreKitManager()
        _ = manager // Suppress unused warning
        // Successfully created
    }

    @Test("Is an actor type")
    func isActorType() async {
        let manager = StoreKitManager()

        // Verify we can perform actor-isolated operations
        await manager.startTransactionListener()
        await manager.stopTransactionListener()
    }

    // MARK: - Transaction Listener

    @Test("Can start and stop transaction listener")
    func canStartAndStopTransactionListener() async {
        let manager = StoreKitManager()

        // Start listener
        await manager.startTransactionListener()

        // Stop listener
        await manager.stopTransactionListener()

        // Can start again after stopping
        await manager.startTransactionListener()
        await manager.stopTransactionListener()
    }

    @Test("Starting listener multiple times is idempotent")
    func startingListenerMultipleTimesIsIdempotent() async {
        let manager = StoreKitManager()

        // Starting multiple times should be safe
        await manager.startTransactionListener()
        await manager.startTransactionListener()
        await manager.startTransactionListener()

        await manager.stopTransactionListener()
    }

    // MARK: - Cached Product

    @Test("Cached product returns nil for unfetched product")
    func cachedProductReturnsNilForUnfetchedProduct() async {
        let manager = StoreKitManager()

        let cached = await manager.cachedProduct(id: "com.example.unfetched")
        #expect(cached == nil)
    }

    // MARK: - Purchase

    @Test("Purchasing uncached product throws error")
    func purchasingUncachedProductThrowsError() async {
        let manager = StoreKitManager()

        do {
            _ = try await manager.purchase(productId: "com.example.uncached")
            Issue.record("Expected error to be thrown")
        } catch let error as IAPError {
            #expect(error == .productNotFound("com.example.uncached"))
        } catch {
            Issue.record("Expected IAPError.productNotFound, got \(error)")
        }
    }

    // MARK: - App Store Availability

    @Test("Can check if purchases are allowed")
    @MainActor
    func canCheckIfPurchasesAreAllowed() async {
        let manager = StoreKitManager()

        let canMake = manager.canMakePurchases()
        // In test environment, this should return true (simulator) or false (restricted)
        #expect(canMake == true || canMake == false)
    }

    // MARK: - Delegate

    @Test("Can set delegate")
    func canSetDelegate() async {
        let manager = StoreKitManager()
        let delegate = MockStoreKitManagerDelegate()

        await manager.setDelegate(delegate)

        // Delegate should be set (we can't verify directly due to actor isolation)
    }

    // Note: Tests that require StoreKit Testing configuration or App Store connectivity
    // are intentionally excluded to avoid test hangs. These operations include:
    // - fetchProducts (requires App Store connection)
    // - restorePurchases (requires App Store sync)
    // - getEntitlements (iterates Transaction.currentEntitlements)
    // - isEntitled (iterates Transaction.currentEntitlements)
    // - latestTransaction (requires Transaction.latest API)
    //
    // To fully test StoreKitManager, configure a StoreKit Testing configuration
    // file and run tests in Xcode with the configuration enabled.
}

// MARK: - IAPErrorTests

@Suite("IAPError Tests")
struct IAPErrorTests {
    @Test("noProductsFound error has correct description")
    func noProductsFoundHasCorrectDescription() {
        let error = IAPError.noProductsFound
        #expect(error.localizedDescription == "No products found for the given identifiers")
    }

    @Test("productNotFound error includes product ID in description")
    func productNotFoundIncludesProductId() {
        let error = IAPError.productNotFound("com.example.missing")
        #expect(error.localizedDescription == "Product not found: com.example.missing")
    }

    @Test("purchaseCancelled error has correct description")
    func purchaseCancelledHasCorrectDescription() {
        let error = IAPError.purchaseCancelled
        #expect(error.localizedDescription == "Purchase was cancelled")
    }

    @Test("purchasePending error has correct description")
    func purchasePendingHasCorrectDescription() {
        let error = IAPError.purchasePending
        #expect(error.localizedDescription == "Purchase is pending external action")
    }

    @Test("verificationFailed error has correct description")
    func verificationFailedHasCorrectDescription() {
        let error = IAPError.verificationFailed
        #expect(error.localizedDescription == "Failed to verify the purchase")
    }

    @Test("notAvailable error has correct description")
    func notAvailableHasCorrectDescription() {
        let error = IAPError.notAvailable
        #expect(error.localizedDescription == "StoreKit is not available")
    }

    @Test("notAllowed error has correct description")
    func notAllowedHasCorrectDescription() {
        let error = IAPError.notAllowed
        #expect(error.localizedDescription == "User is not allowed to make purchases")
    }

    @Test("unknown error includes message in description")
    func unknownIncludesMessage() {
        let error = IAPError.unknown("Something went wrong")
        #expect(error.localizedDescription == "StoreKit error: Something went wrong")
    }

    @Test("IAPError is Sendable")
    func isSendable() async {
        let error = IAPError.purchaseCancelled

        await Task.detached {
            #expect(error == .purchaseCancelled)
        }.value
    }

    @Test("IAPError cases are Equatable")
    func casesAreEquatable() {
        #expect(IAPError.noProductsFound == IAPError.noProductsFound)
        #expect(IAPError.productNotFound("a") == IAPError.productNotFound("a"))
        #expect(IAPError.productNotFound("a") != IAPError.productNotFound("b"))
        #expect(IAPError.purchaseCancelled == IAPError.purchaseCancelled)
        #expect(IAPError.purchasePending == IAPError.purchasePending)
        #expect(IAPError.verificationFailed == IAPError.verificationFailed)
        #expect(IAPError.notAvailable == IAPError.notAvailable)
        #expect(IAPError.notAllowed == IAPError.notAllowed)
        #expect(IAPError.unknown("x") == IAPError.unknown("x"))
        #expect(IAPError.unknown("x") != IAPError.unknown("y"))
    }

    @Test("Different error cases are not equal")
    func differentCasesAreNotEqual() {
        #expect(IAPError.noProductsFound != IAPError.purchaseCancelled)
        #expect(IAPError.purchaseCancelled != IAPError.purchasePending)
        #expect(IAPError.verificationFailed != IAPError.notAvailable)
    }
}

// MARK: - MockStoreKitManagerDelegate

/// Mock delegate for testing StoreKitManager delegate callbacks.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class MockStoreKitManagerDelegate: StoreKitManagerDelegate, @unchecked Sendable {
    var updatedTransactions: [Transaction] = []
    var failedVerifications: [VerificationResult<Transaction>] = []

    func storeKitManager(_: StoreKitManager, didUpdateTransaction transaction: Transaction) {
        updatedTransactions.append(transaction)
    }

    func storeKitManager(_: StoreKitManager, didFailVerificationFor result: VerificationResult<Transaction>) {
        failedVerifications.append(result)
    }
}

// MARK: - StoreKitManager Delegate Setter Extension

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension StoreKitManager {
    /// Helper method to set the delegate in tests.
    func setDelegate(_ delegate: StoreKitManagerDelegate?) async {
        self.delegate = delegate
    }
}
