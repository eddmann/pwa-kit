import Foundation

// MARK: - ProductType

/// The type of in-app purchase product.
///
/// This enum maps to StoreKit 2 product types and is used to
/// communicate the product type to JavaScript.
///
/// ## Example
///
/// ```swift
/// let type = ProductType.consumable
/// let encoded = try JSONEncoder().encode(type)
/// // "consumable"
/// ```
public enum ProductType: String, Codable, Sendable, Equatable, CaseIterable {
    /// A consumable product that can be purchased multiple times.
    case consumable

    /// A non-consumable product that is purchased once and owned forever.
    case nonConsumable = "non_consumable"

    /// An auto-renewable subscription.
    case autoRenewable = "auto_renewable"

    /// A non-renewing subscription.
    case nonRenewing = "non_renewing"
}

// MARK: - ProductInfo

/// Information about a product available for purchase.
///
/// This type represents a product from the App Store, containing
/// all the information needed to display and purchase the product.
///
/// ## Example
///
/// ```json
/// {
///   "id": "com.example.premium",
///   "displayName": "Premium Upgrade",
///   "displayPrice": "$4.99",
///   "type": "non_consumable",
///   "description": "Unlock all premium features"
/// }
/// ```
public struct ProductInfo: Codable, Sendable, Equatable {
    /// The unique product identifier.
    public let id: String

    /// The localized display name of the product.
    public let displayName: String

    /// The localized display price, including currency symbol.
    public let displayPrice: String

    /// The type of product.
    public let type: ProductType

    /// The localized description of the product.
    public let description: String?

    /// Creates a new product info.
    ///
    /// - Parameters:
    ///   - id: The unique product identifier.
    ///   - displayName: The localized display name.
    ///   - displayPrice: The localized display price with currency.
    ///   - type: The type of product.
    ///   - description: The localized description.
    public init(
        id: String,
        displayName: String,
        displayPrice: String,
        type: ProductType,
        description: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.type = type
        self.description = description
    }
}

// MARK: - PurchaseResult

/// The result of a purchase attempt.
///
/// When a purchase is initiated, this type contains the outcome
/// including the transaction ID on success or error information on failure.
///
/// ## Example
///
/// Successful purchase:
/// ```json
/// {
///   "success": true,
///   "transactionId": "1000000123456789",
///   "productId": "com.example.premium"
/// }
/// ```
///
/// Failed purchase:
/// ```json
/// {
///   "success": false,
///   "error": "User cancelled the purchase",
///   "productId": "com.example.premium"
/// }
/// ```
public struct PurchaseResult: Codable, Sendable, Equatable {
    /// Whether the purchase was successful.
    public let success: Bool

    /// The transaction identifier, present on success.
    public let transactionId: String?

    /// The product identifier for this purchase.
    public let productId: String

    /// Error message if the purchase failed.
    public let error: String?

    /// Creates a successful purchase result.
    ///
    /// - Parameters:
    ///   - transactionId: The StoreKit transaction identifier.
    ///   - productId: The product identifier that was purchased.
    public init(transactionId: String, productId: String) {
        self.success = true
        self.transactionId = transactionId
        self.productId = productId
        self.error = nil
    }

    /// Creates a failed purchase result.
    ///
    /// - Parameters:
    ///   - error: A description of why the purchase failed.
    ///   - productId: The product identifier that was attempted.
    public init(error: String, productId: String) {
        self.success = false
        self.transactionId = nil
        self.productId = productId
        self.error = error
    }

    /// Creates a purchase result with all fields.
    ///
    /// This initializer is primarily used for decoding.
    ///
    /// - Parameters:
    ///   - success: Whether the purchase was successful.
    ///   - transactionId: The transaction identifier, if available.
    ///   - productId: The product identifier.
    ///   - error: Error message, if any.
    public init(
        success: Bool,
        transactionId: String?,
        productId: String,
        error: String?
    ) {
        self.success = success
        self.transactionId = transactionId
        self.productId = productId
        self.error = error
    }
}

// MARK: - EntitlementInfo

/// Information about the user's entitlements (purchased products).
///
/// This type represents the products that the user currently owns,
/// including active subscriptions and non-consumable purchases.
///
/// ## Example
///
/// ```json
/// {
///   "productIds": ["com.example.premium", "com.example.subscription.monthly"],
///   "activeSubscriptions": ["com.example.subscription.monthly"]
/// }
/// ```
public struct EntitlementInfo: Codable, Sendable, Equatable {
    /// The IDs of all products the user has purchased and owns.
    /// This includes non-consumable purchases and active subscriptions.
    public let productIds: [String]

    /// The IDs of currently active subscriptions.
    /// These are subscriptions that have not expired or been cancelled.
    public let activeSubscriptions: [String]

    /// Creates an entitlement info.
    ///
    /// - Parameters:
    ///   - productIds: The IDs of all owned products.
    ///   - activeSubscriptions: The IDs of active subscriptions.
    public init(productIds: [String], activeSubscriptions: [String] = []) {
        self.productIds = productIds
        self.activeSubscriptions = activeSubscriptions
    }

    /// Creates an empty entitlement info (no purchases).
    public static let empty = EntitlementInfo(productIds: [], activeSubscriptions: [])
}

// MARK: - GetProductsRequest

/// Request payload for fetching products.
///
/// ## Example
///
/// ```json
/// {
///   "productIds": ["com.example.premium", "com.example.coins.100"]
/// }
/// ```
public struct GetProductsRequest: Codable, Sendable, Equatable {
    /// The product identifiers to fetch.
    public let productIds: [String]

    /// Creates a get products request.
    ///
    /// - Parameter productIds: The product identifiers to fetch.
    public init(productIds: [String]) {
        self.productIds = productIds
    }
}

// MARK: - PurchaseRequest

/// Request payload for initiating a purchase.
///
/// ## Example
///
/// ```json
/// {
///   "productId": "com.example.premium"
/// }
/// ```
public struct PurchaseRequest: Codable, Sendable, Equatable {
    /// The product identifier to purchase.
    public let productId: String

    /// Creates a purchase request.
    ///
    /// - Parameter productId: The product identifier to purchase.
    public init(productId: String) {
        self.productId = productId
    }
}

// MARK: - GetProductsResponse

/// Response containing a list of products.
///
/// ## Example
///
/// ```json
/// {
///   "products": [
///     {
///       "id": "com.example.premium",
///       "displayName": "Premium",
///       "displayPrice": "$4.99",
///       "type": "non_consumable"
///     }
///   ]
/// }
/// ```
public struct GetProductsResponse: Codable, Sendable, Equatable {
    /// The list of products that were fetched.
    public let products: [ProductInfo]

    /// Creates a get products response.
    ///
    /// - Parameter products: The list of products.
    public init(products: [ProductInfo]) {
        self.products = products
    }
}

// MARK: - RestoreResult

/// Response for restore purchases operation.
///
/// ## Example
///
/// Successful restore:
/// ```json
/// {
///   "success": true,
///   "restoredProductIds": ["com.example.premium"]
/// }
/// ```
///
/// Failed restore:
/// ```json
/// {
///   "success": false,
///   "error": "Unable to restore purchases"
/// }
/// ```
public struct RestoreResult: Codable, Sendable, Equatable {
    /// Whether the restore operation was successful.
    public let success: Bool

    /// The IDs of products that were restored.
    public let restoredProductIds: [String]?

    /// Error message if the restore failed.
    public let error: String?

    /// Creates a successful restore result.
    ///
    /// - Parameter restoredProductIds: The IDs of restored products.
    public init(restoredProductIds: [String]) {
        self.success = true
        self.restoredProductIds = restoredProductIds
        self.error = nil
    }

    /// Creates a failed restore result.
    ///
    /// - Parameter error: A description of why the restore failed.
    public init(error: String) {
        self.success = false
        self.restoredProductIds = nil
        self.error = error
    }

    /// Creates a restore result with all fields.
    ///
    /// This initializer is primarily used for decoding.
    ///
    /// - Parameters:
    ///   - success: Whether the restore was successful.
    ///   - restoredProductIds: The restored product IDs, if available.
    ///   - error: Error message, if any.
    public init(
        success: Bool,
        restoredProductIds: [String]?,
        error: String?
    ) {
        self.success = success
        self.restoredProductIds = restoredProductIds
        self.error = error
    }
}
