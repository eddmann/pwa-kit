import Foundation
import StoreKit

// MARK: - IAPModule

/// A module that provides in-app purchase functionality to JavaScript.
///
/// `IAPModule` exposes StoreKit 2 operations to web applications, allowing
/// them to fetch products, make purchases, restore purchases, and check
/// user entitlements.
///
/// ## Supported Actions
///
/// - `getProducts`: Fetch product information from the App Store.
///   - `productIds`: Required array of product identifiers to fetch.
///   - Returns `{ products: [...] }` with product details.
///
/// - `purchase`: Initiate a purchase for a specific product.
///   - `productId`: Required product identifier to purchase.
///   - Returns `PurchaseResult` with transaction ID on success.
///
/// - `restore`: Restore previously purchased products.
///   - Returns `RestoreResult` with restored product IDs.
///
/// - `getEntitlements`: Get the user's currently owned products.
///   - Returns `EntitlementInfo` with owned product IDs.
///
/// ## Example
///
/// JavaScript request to fetch products:
/// ```json
/// {
///   "id": "abc-123",
///   "module": "iap",
///   "action": "getProducts",
///   "payload": {
///     "productIds": ["com.example.premium", "com.example.coins.100"]
///   }
/// }
/// ```
///
/// Response:
/// ```json
/// {
///   "id": "abc-123",
///   "success": true,
///   "data": {
///     "products": [
///       {
///         "id": "com.example.premium",
///         "displayName": "Premium Upgrade",
///         "displayPrice": "$4.99",
///         "type": "non_consumable",
///         "description": "Unlock all features"
///       }
///     ]
///   }
/// }
/// ```
///
/// JavaScript request to purchase:
/// ```json
/// {
///   "id": "def-456",
///   "module": "iap",
///   "action": "purchase",
///   "payload": {
///     "productId": "com.example.premium"
///   }
/// }
/// ```
///
/// Success response:
/// ```json
/// {
///   "id": "def-456",
///   "success": true,
///   "data": {
///     "success": true,
///     "transactionId": "1000000123456789",
///     "productId": "com.example.premium"
///   }
/// }
/// ```
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct IAPModule: PWAModule {
    public static let moduleName = "iap"
    public static let supportedActions = ["getProducts", "purchase", "restore", "getEntitlements"]

    /// The StoreKit manager used for IAP operations.
    private let storeKitManager: StoreKitManager

    /// Creates a new IAP module with a default StoreKit manager.
    public init() {
        self.storeKitManager = StoreKitManager()
    }

    /// Creates a new IAP module with a custom StoreKit manager.
    ///
    /// - Parameter storeKitManager: The StoreKit manager to use for operations.
    public init(storeKitManager: StoreKitManager) {
        self.storeKitManager = storeKitManager
    }

    public func handle(
        action: String,
        payload: AnyCodable?,
        context _: ModuleContext
    ) async throws -> AnyCodable? {
        try validateAction(action)

        switch action {
        case "getProducts":
            return try await handleGetProducts(payload: payload)

        case "purchase":
            return try await handlePurchase(payload: payload)

        case "restore":
            return try await handleRestore()

        case "getEntitlements":
            return await handleGetEntitlements()

        default:
            throw BridgeError.unknownAction(action)
        }
    }

    // MARK: - Get Products Action

    /// Handles the `getProducts` action to fetch product information.
    ///
    /// - Parameter payload: Dictionary containing `productIds` array.
    /// - Returns: A `GetProductsResponse` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if productIds is missing or empty.
    private func handleGetProducts(payload: AnyCodable?) async throws -> AnyCodable {
        guard let productIdsArray = payload?["productIds"]?.arrayValue else {
            throw BridgeError.invalidPayload("Missing required 'productIds' array")
        }

        let productIds = productIdsArray.compactMap(\.stringValue)

        guard !productIds.isEmpty else {
            throw BridgeError.invalidPayload("'productIds' array must contain at least one product ID")
        }

        do {
            let products = try await storeKitManager.fetchProducts(ids: productIds)
            let response = GetProductsResponse(products: products)
            return encodeResponse(response)
        } catch let error as IAPError {
            throw BridgeError.moduleError(underlying: error)
        } catch {
            throw BridgeError.moduleError(underlying: error)
        }
    }

    // MARK: - Purchase Action

    /// Handles the `purchase` action to initiate a product purchase.
    ///
    /// - Parameter payload: Dictionary containing `productId`.
    /// - Returns: A `PurchaseResult` encoded as `AnyCodable`.
    /// - Throws: `BridgeError.invalidPayload` if productId is missing.
    private func handlePurchase(payload: AnyCodable?) async throws -> AnyCodable {
        guard let productId = payload?["productId"]?.stringValue else {
            throw BridgeError.invalidPayload("Missing required 'productId' field")
        }

        do {
            let result = try await storeKitManager.purchase(productId: productId)
            return encodeResponse(result)
        } catch let error as IAPError {
            // Return a failure result rather than throwing for expected purchase failures
            let errorMessage = error.errorDescription ?? "Unknown error"
            let result = PurchaseResult(error: errorMessage, productId: productId)
            return encodeResponse(result)
        } catch {
            let result = PurchaseResult(error: error.localizedDescription, productId: productId)
            return encodeResponse(result)
        }
    }

    // MARK: - Restore Action

    /// Handles the `restore` action to restore previous purchases.
    ///
    /// - Returns: A `RestoreResult` encoded as `AnyCodable`.
    private func handleRestore() async throws -> AnyCodable {
        do {
            let result = try await storeKitManager.restorePurchases()
            return encodeResponse(result)
        } catch let error as IAPError {
            let errorMessage = error.errorDescription ?? "Unknown error"
            let result = RestoreResult(error: errorMessage)
            return encodeResponse(result)
        } catch {
            let result = RestoreResult(error: error.localizedDescription)
            return encodeResponse(result)
        }
    }

    // MARK: - Get Entitlements Action

    /// Handles the `getEntitlements` action to get owned products.
    ///
    /// - Returns: An `EntitlementInfo` encoded as `AnyCodable`.
    private func handleGetEntitlements() async -> AnyCodable {
        let entitlements = await storeKitManager.getEntitlements()
        return encodeResponse(entitlements)
    }

    // MARK: - Helpers

    /// Encodes a Codable response to AnyCodable.
    ///
    /// This converts a strongly-typed response to the dynamic AnyCodable
    /// format used by the bridge.
    private func encodeResponse(_ response: some Encodable) -> AnyCodable {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            let decoder = JSONDecoder()
            return try decoder.decode(AnyCodable.self, from: data)
        } catch {
            // Fallback to a simple error response if encoding fails
            return AnyCodable([
                "error": AnyCodable("Failed to encode response: \(error.localizedDescription)"),
            ])
        }
    }
}

// MARK: @unchecked Sendable

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension IAPModule: @unchecked Sendable {
    // StoreKitManager is an actor, so it's thread-safe.
    // The IAPModule itself is a struct with no mutable state,
    // making it safe to mark as @unchecked Sendable.
}
