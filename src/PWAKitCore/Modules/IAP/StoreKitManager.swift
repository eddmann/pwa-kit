import Foundation
import StoreKit

// MARK: - IAPError

/// Error types specific to StoreKit operations.
///
/// These errors provide more specific information about IAP failures
/// than the generic `BridgeError` type.
public enum IAPError: Error, Sendable, Equatable, LocalizedError {
    /// No products were found for the given IDs.
    case noProductsFound

    /// The specified product was not found.
    case productNotFound(String)

    /// The purchase was cancelled by the user.
    case purchaseCancelled

    /// The purchase is pending (requires external action).
    case purchasePending

    /// The App Store could not verify the purchase.
    case verificationFailed

    /// StoreKit is not available on this device/platform.
    case notAvailable

    /// The user is not allowed to make purchases.
    case notAllowed

    /// An unknown StoreKit error occurred.
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .noProductsFound:
            "No products found for the given identifiers"
        case let .productNotFound(productId):
            "Product not found: \(productId)"
        case .purchaseCancelled:
            "Purchase was cancelled"
        case .purchasePending:
            "Purchase is pending external action"
        case .verificationFailed:
            "Failed to verify the purchase"
        case .notAvailable:
            "StoreKit is not available"
        case .notAllowed:
            "User is not allowed to make purchases"
        case let .unknown(message):
            "StoreKit error: \(message)"
        }
    }
}

// MARK: - StoreKitManager

/// Manages StoreKit 2 in-app purchase operations.
///
/// `StoreKitManager` provides an async/await interface for:
/// - Fetching products from the App Store
/// - Purchasing products
/// - Restoring previous purchases
/// - Monitoring transaction updates
/// - Checking user entitlements
///
/// ## Usage
///
/// ```swift
/// let manager = StoreKitManager()
/// await manager.startTransactionListener()
///
/// // Fetch products
/// let products = try await manager.fetchProducts(ids: ["com.example.premium"])
///
/// // Purchase
/// let result = try await manager.purchase(productId: "com.example.premium")
///
/// // Check entitlements
/// let entitlements = await manager.getEntitlements()
/// ```
///
/// ## Transaction Listener
///
/// Call `startTransactionListener()` during app launch to handle
/// transactions that occur outside the app (e.g., subscription renewals,
/// family sharing, ask-to-buy approvals).
///
/// ## Thread Safety
///
/// `StoreKitManager` is implemented as an actor to ensure thread-safe
/// access to its internal state, particularly the products cache and
/// transaction listener.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public actor StoreKitManager {
    /// Cached products from the last fetch operation.
    private var cachedProducts: [String: Product] = [:]

    /// Task for the transaction update listener.
    private var transactionListenerTask: Task<Void, Never>?

    /// Delegate to notify of transaction updates.
    public weak var delegate: StoreKitManagerDelegate?

    /// Creates a new StoreKit manager.
    public init() {}

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    /// Starts listening for transaction updates.
    ///
    /// This should be called during app launch to handle transactions
    /// that occur outside the app, such as:
    /// - Subscription renewals
    /// - Family sharing changes
    /// - Ask-to-buy approvals
    /// - Refunds
    ///
    /// The listener runs until `stopTransactionListener()` is called
    /// or the manager is deallocated.
    public func startTransactionListener() {
        guard transactionListenerTask == nil else { return }

        transactionListenerTask = Task {
            for await verificationResult in Transaction.updates {
                await handleTransactionUpdate(verificationResult)
            }
        }
    }

    /// Stops the transaction update listener.
    public func stopTransactionListener() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
    }

    /// Handles a transaction update from the listener.
    private func handleTransactionUpdate(_ verificationResult: VerificationResult<Transaction>) async {
        guard let transaction = checkVerification(verificationResult) else {
            // Verification failed
            delegate?.storeKitManager(self, didFailVerificationFor: verificationResult)
            return
        }

        // Always finish the transaction
        await transaction.finish()

        // Notify delegate
        delegate?.storeKitManager(self, didUpdateTransaction: transaction)
    }

    /// Verifies a transaction result and returns the transaction if valid.
    private func checkVerification<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .unverified:
            nil
        case let .verified(value):
            value
        }
    }

    // MARK: - Fetch Products

    /// Fetches products from the App Store.
    ///
    /// Products are cached for subsequent access via `cachedProduct(id:)`.
    ///
    /// - Parameter ids: The product identifiers to fetch.
    /// - Returns: An array of product information.
    /// - Throws: `StoreKitError.noProductsFound` if no products match the IDs.
    public func fetchProducts(ids: [String]) async throws -> [ProductInfo] {
        let products = try await Product.products(for: Set(ids))

        guard !products.isEmpty else {
            throw IAPError.noProductsFound
        }

        // Cache products for later use
        for product in products {
            cachedProducts[product.id] = product
        }

        return products.map { productInfoFrom($0) }
    }

    /// Returns a cached product by ID, if available.
    ///
    /// Products must be fetched first via `fetchProducts(ids:)`.
    ///
    /// - Parameter id: The product identifier.
    /// - Returns: The cached product, or nil if not cached.
    public func cachedProduct(id: String) -> Product? {
        cachedProducts[id]
    }

    /// Converts a StoreKit Product to our ProductInfo type.
    private func productInfoFrom(_ product: Product) -> ProductInfo {
        ProductInfo(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            type: productTypeFrom(product.type),
            description: product.description
        )
    }

    /// Converts a StoreKit Product.ProductType to our ProductType enum.
    private func productTypeFrom(_ type: Product.ProductType) -> ProductType {
        switch type {
        case .consumable:
            .consumable
        case .nonConsumable:
            .nonConsumable
        case .autoRenewable:
            .autoRenewable
        case .nonRenewable:
            .nonRenewing
        default:
            .consumable
        }
    }

    // MARK: - Purchase

    /// Purchases a product.
    ///
    /// The product must have been previously fetched via `fetchProducts(ids:)`.
    ///
    /// - Parameter productId: The product identifier to purchase.
    /// - Returns: The purchase result with transaction ID on success.
    /// - Throws: Various `StoreKitError` cases depending on failure reason.
    public func purchase(productId: String) async throws -> PurchaseResult {
        guard let product = cachedProducts[productId] else {
            throw IAPError.productNotFound(productId)
        }

        return try await purchase(product: product)
    }

    /// Purchases a product directly.
    ///
    /// - Parameter product: The StoreKit product to purchase.
    /// - Returns: The purchase result with transaction ID on success.
    /// - Throws: Various `StoreKitError` cases depending on failure reason.
    public func purchase(product: Product) async throws -> PurchaseResult {
        let result: Product.PurchaseResult

        do {
            result = try await product.purchase()
        } catch {
            throw IAPError.unknown(error.localizedDescription)
        }

        switch result {
        case let .success(verificationResult):
            guard let transaction = checkVerification(verificationResult) else {
                throw IAPError.verificationFailed
            }

            // Finish the transaction
            await transaction.finish()

            return PurchaseResult(
                transactionId: String(transaction.id),
                productId: product.id
            )

        case .userCancelled:
            throw IAPError.purchaseCancelled

        case .pending:
            throw IAPError.purchasePending

        @unknown default:
            throw IAPError.unknown("Unknown purchase result")
        }
    }

    // MARK: - Restore Purchases

    /// Restores previously purchased products.
    ///
    /// This syncs the user's transaction history with the App Store
    /// and returns all restored product IDs.
    ///
    /// - Returns: A restore result with the IDs of restored products.
    /// - Throws: `StoreKitError` if restore fails.
    public func restorePurchases() async throws -> RestoreResult {
        // Sync with App Store
        do {
            try await AppStore.sync()
        } catch {
            throw IAPError.unknown(error.localizedDescription)
        }

        // Get all current entitlements
        var restoredIds: [String] = []

        for await verificationResult in Transaction.currentEntitlements {
            guard let transaction = checkVerification(verificationResult) else {
                continue
            }
            restoredIds.append(transaction.productID)
        }

        return RestoreResult(restoredProductIds: restoredIds)
    }

    // MARK: - Entitlements

    /// Gets the user's current entitlements.
    ///
    /// Entitlements include:
    /// - Non-consumable purchases
    /// - Active auto-renewable subscriptions
    /// - Active non-renewing subscriptions
    ///
    /// - Returns: The user's entitlement information.
    public func getEntitlements() async -> EntitlementInfo {
        var productIds: [String] = []
        var activeSubscriptions: [String] = []

        for await verificationResult in Transaction.currentEntitlements {
            guard let transaction = checkVerification(verificationResult) else {
                continue
            }

            productIds.append(transaction.productID)

            // Check if it's an active subscription
            if transaction.productType == .autoRenewable,
               transaction.expirationDate ?? Date.distantFuture > Date()
            {
                activeSubscriptions.append(transaction.productID)
            }
        }

        return EntitlementInfo(
            productIds: productIds,
            activeSubscriptions: activeSubscriptions
        )
    }

    /// Checks if the user owns a specific product.
    ///
    /// - Parameter productId: The product identifier to check.
    /// - Returns: `true` if the user owns the product.
    public func isEntitled(to productId: String) async -> Bool {
        for await verificationResult in Transaction.currentEntitlements {
            guard let transaction = checkVerification(verificationResult) else {
                continue
            }
            if transaction.productID == productId {
                return true
            }
        }
        return false
    }

    /// Gets the latest transaction for a product, if any.
    ///
    /// - Parameter productId: The product identifier.
    /// - Returns: The latest transaction, or nil if no purchase exists.
    public func latestTransaction(for productId: String) async -> Transaction? {
        guard let verificationResult = await Transaction.latest(for: productId) else {
            return nil
        }
        return checkVerification(verificationResult)
    }

    // MARK: - App Store Availability

    /// Checks if the user can make purchases.
    ///
    /// This returns false if:
    /// - The device is in a restricted mode
    /// - Parental controls prevent purchases
    /// - The App Store is unavailable
    ///
    /// - Returns: `true` if purchases are allowed.
    @MainActor
    public func canMakePurchases() -> Bool {
        AppStore.canMakePayments
    }
}

// MARK: - StoreKitManagerDelegate

/// Delegate protocol for receiving StoreKit manager updates.
///
/// Implement this protocol to receive notifications about
/// transaction updates that occur outside the normal purchase flow.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public protocol StoreKitManagerDelegate: AnyObject, Sendable {
    /// Called when a transaction is updated.
    ///
    /// This can be called for:
    /// - Subscription renewals
    /// - Family sharing changes
    /// - Ask-to-buy approvals
    /// - Refunds
    ///
    /// - Parameters:
    ///   - manager: The StoreKit manager.
    ///   - transaction: The updated transaction.
    func storeKitManager(_ manager: StoreKitManager, didUpdateTransaction transaction: Transaction)

    /// Called when a transaction fails verification.
    ///
    /// - Parameters:
    ///   - manager: The StoreKit manager.
    ///   - result: The unverified transaction result.
    func storeKitManager(_ manager: StoreKitManager, didFailVerificationFor result: VerificationResult<Transaction>)
}

// MARK: - Default Delegate Implementation

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension StoreKitManagerDelegate {
    /// Default implementation does nothing.
    public func storeKitManager(_: StoreKitManager, didUpdateTransaction _: Transaction) {}

    /// Default implementation does nothing.
    public func storeKitManager(_: StoreKitManager, didFailVerificationFor _: VerificationResult<Transaction>) {}
}
