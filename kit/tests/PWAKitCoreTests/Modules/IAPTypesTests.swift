import Foundation
import Testing

@testable import PWAKitApp

@Suite("IAPTypes Tests")
struct IAPTypesTests {
    // MARK: - ProductType Tests

    @Suite("ProductType")
    struct ProductTypeTests {
        @Test("Encodes to expected JSON string values")
        func encodesToExpectedValues() throws {
            let encoder = JSONEncoder()

            let consumable = try encoder.encode(ProductType.consumable)
            #expect(String(data: consumable, encoding: .utf8) == "\"consumable\"")

            let nonConsumable = try encoder.encode(ProductType.nonConsumable)
            #expect(String(data: nonConsumable, encoding: .utf8) == "\"non_consumable\"")

            let autoRenewable = try encoder.encode(ProductType.autoRenewable)
            #expect(String(data: autoRenewable, encoding: .utf8) == "\"auto_renewable\"")

            let nonRenewing = try encoder.encode(ProductType.nonRenewing)
            #expect(String(data: nonRenewing, encoding: .utf8) == "\"non_renewing\"")
        }

        @Test("Decodes from JSON string values")
        func decodesFromJSONStrings() throws {
            let decoder = JSONDecoder()

            let consumable = try decoder.decode(
                ProductType.self,
                from: "\"consumable\"".data(using: .utf8)!
            )
            #expect(consumable == .consumable)

            let nonConsumable = try decoder.decode(
                ProductType.self,
                from: "\"non_consumable\"".data(using: .utf8)!
            )
            #expect(nonConsumable == .nonConsumable)

            let autoRenewable = try decoder.decode(
                ProductType.self,
                from: "\"auto_renewable\"".data(using: .utf8)!
            )
            #expect(autoRenewable == .autoRenewable)

            let nonRenewing = try decoder.decode(
                ProductType.self,
                from: "\"non_renewing\"".data(using: .utf8)!
            )
            #expect(nonRenewing == .nonRenewing)
        }

        @Test("Throws error for invalid value")
        func throwsForInvalidValue() {
            let decoder = JSONDecoder()

            #expect(throws: DecodingError.self) {
                _ = try decoder.decode(
                    ProductType.self,
                    from: "\"invalid\"".data(using: .utf8)!
                )
            }
        }

        @Test("Is Sendable")
        func isSendable() async {
            let type = ProductType.nonConsumable

            await Task.detached {
                #expect(type == .nonConsumable)
            }.value
        }

        @Test("All cases are defined")
        func allCasesAreDefined() {
            let allCases = ProductType.allCases
            #expect(allCases.count == 4)
            #expect(allCases.contains(.consumable))
            #expect(allCases.contains(.nonConsumable))
            #expect(allCases.contains(.autoRenewable))
            #expect(allCases.contains(.nonRenewing))
        }
    }

    // MARK: - ProductInfo Tests

    @Suite("ProductInfo")
    struct ProductInfoTests {
        @Test("Encodes with all fields")
        func encodesWithAllFields() throws {
            let product = ProductInfo(
                id: "com.example.premium",
                displayName: "Premium Upgrade",
                displayPrice: "$4.99",
                type: .nonConsumable,
                description: "Unlock all premium features"
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(product)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"id\":\"com.example.premium\""))
            #expect(json.contains("\"displayName\":\"Premium Upgrade\""))
            #expect(json.contains("\"displayPrice\":\"$4.99\""))
            #expect(json.contains("\"type\":\"non_consumable\""))
            #expect(json.contains("\"description\":\"Unlock all premium features\""))
        }

        @Test("Encodes with minimal fields")
        func encodesWithMinimalFields() throws {
            let product = ProductInfo(
                id: "com.example.coins",
                displayName: "100 Coins",
                displayPrice: "$0.99",
                type: .consumable
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(product)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"id\":\"com.example.coins\""))
            #expect(json.contains("\"displayName\":\"100 Coins\""))
            #expect(json.contains("\"displayPrice\":\"$0.99\""))
            #expect(json.contains("\"type\":\"consumable\""))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "id": "com.example.subscription",
                "displayName": "Monthly Plan",
                "displayPrice": "$9.99/mo",
                "type": "auto_renewable",
                "description": "Full access subscription"
            }
            """

            let decoder = JSONDecoder()
            let product = try decoder.decode(
                ProductInfo.self,
                from: json.data(using: .utf8)!
            )

            #expect(product.id == "com.example.subscription")
            #expect(product.displayName == "Monthly Plan")
            #expect(product.displayPrice == "$9.99/mo")
            #expect(product.type == .autoRenewable)
            #expect(product.description == "Full access subscription")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = ProductInfo(
                id: "com.example.test",
                displayName: "Test Product",
                displayPrice: "$1.99",
                type: .nonRenewing,
                description: "A test product"
            )

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ProductInfo.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let product = ProductInfo(
                id: "com.example.test",
                displayName: "Test",
                displayPrice: "$1.99",
                type: .consumable
            )

            await Task.detached {
                #expect(product.id == "com.example.test")
            }.value
        }
    }

    // MARK: - PurchaseResult Tests

    @Suite("PurchaseResult")
    struct PurchaseResultTests {
        @Test("Successful purchase encodes correctly")
        func successfulPurchaseEncodes() throws {
            let result = PurchaseResult(
                transactionId: "1000000123456789",
                productId: "com.example.premium"
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(result)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":true"))
            #expect(json.contains("\"transactionId\":\"1000000123456789\""))
            #expect(json.contains("\"productId\":\"com.example.premium\""))
            #expect(!json.contains("\"error\"") || json.contains("\"error\":null"))
        }

        @Test("Failed purchase encodes correctly")
        func failedPurchaseEncodes() throws {
            let result = PurchaseResult(
                error: "User cancelled the purchase",
                productId: "com.example.premium"
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(result)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":false"))
            #expect(!json.contains("\"transactionId\"") || json.contains("\"transactionId\":null"))
            #expect(json.contains("\"productId\":\"com.example.premium\""))
            #expect(json.contains("\"error\":\"User cancelled the purchase\""))
        }

        @Test("Decodes successful purchase from JSON")
        func decodesSuccessfulFromJSON() throws {
            let json = """
            {
                "success": true,
                "transactionId": "txn-123",
                "productId": "com.example.coins",
                "error": null
            }
            """

            let decoder = JSONDecoder()
            let result = try decoder.decode(
                PurchaseResult.self,
                from: json.data(using: .utf8)!
            )

            #expect(result.success == true)
            #expect(result.transactionId == "txn-123")
            #expect(result.productId == "com.example.coins")
            #expect(result.error == nil)
        }

        @Test("Decodes failed purchase from JSON")
        func decodesFailedFromJSON() throws {
            let json = """
            {
                "success": false,
                "transactionId": null,
                "productId": "com.example.coins",
                "error": "Payment declined"
            }
            """

            let decoder = JSONDecoder()
            let result = try decoder.decode(
                PurchaseResult.self,
                from: json.data(using: .utf8)!
            )

            #expect(result.success == false)
            #expect(result.transactionId == nil)
            #expect(result.productId == "com.example.coins")
            #expect(result.error == "Payment declined")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = PurchaseResult(
                transactionId: "test-txn",
                productId: "com.example.test"
            )

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(PurchaseResult.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let result = PurchaseResult(
                transactionId: "txn-123",
                productId: "com.example.test"
            )

            await Task.detached {
                #expect(result.success == true)
            }.value
        }

        @Test("Convenience initializer for success sets correct values")
        func successInitializerSetsCorrectValues() {
            let result = PurchaseResult(
                transactionId: "my-txn",
                productId: "com.example.product"
            )

            #expect(result.success == true)
            #expect(result.transactionId == "my-txn")
            #expect(result.productId == "com.example.product")
            #expect(result.error == nil)
        }

        @Test("Convenience initializer for failure sets correct values")
        func failureInitializerSetsCorrectValues() {
            let result = PurchaseResult(
                error: "Something went wrong",
                productId: "com.example.product"
            )

            #expect(result.success == false)
            #expect(result.transactionId == nil)
            #expect(result.productId == "com.example.product")
            #expect(result.error == "Something went wrong")
        }
    }

    // MARK: - EntitlementInfo Tests

    @Suite("EntitlementInfo")
    struct EntitlementInfoTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let entitlements = EntitlementInfo(
                productIds: ["com.example.premium", "com.example.feature"],
                activeSubscriptions: ["com.example.subscription"]
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(entitlements)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"productIds\":[\"com.example.premium\",\"com.example.feature\"]"))
            #expect(json.contains("\"activeSubscriptions\":[\"com.example.subscription\"]"))
        }

        @Test("Encodes empty entitlements")
        func encodesEmptyEntitlements() throws {
            let entitlements = EntitlementInfo.empty

            let encoder = JSONEncoder()
            let data = try encoder.encode(entitlements)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"productIds\":[]"))
            #expect(json.contains("\"activeSubscriptions\":[]"))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "productIds": ["com.example.a", "com.example.b"],
                "activeSubscriptions": ["com.example.a"]
            }
            """

            let decoder = JSONDecoder()
            let entitlements = try decoder.decode(
                EntitlementInfo.self,
                from: json.data(using: .utf8)!
            )

            #expect(entitlements.productIds == ["com.example.a", "com.example.b"])
            #expect(entitlements.activeSubscriptions == ["com.example.a"])
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = EntitlementInfo(
                productIds: ["id1", "id2", "id3"],
                activeSubscriptions: ["id1"]
            )

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(EntitlementInfo.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let entitlements = EntitlementInfo(
                productIds: ["test"],
                activeSubscriptions: []
            )

            await Task.detached {
                #expect(entitlements.productIds.count == 1)
            }.value
        }

        @Test("Empty static property has correct values")
        func emptyStaticProperty() {
            let empty = EntitlementInfo.empty

            #expect(empty.productIds.isEmpty)
            #expect(empty.activeSubscriptions.isEmpty)
        }

        @Test("Convenience initializer defaults activeSubscriptions to empty")
        func initializerDefaultsActiveSubscriptions() {
            let entitlements = EntitlementInfo(productIds: ["com.example.test"])

            #expect(entitlements.productIds == ["com.example.test"])
            #expect(entitlements.activeSubscriptions.isEmpty)
        }
    }

    // MARK: - GetProductsRequest Tests

    @Suite("GetProductsRequest")
    struct GetProductsRequestTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let request = GetProductsRequest(productIds: ["id1", "id2"])

            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"productIds\":[\"id1\",\"id2\"]"))
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = "{\"productIds\":[\"com.example.a\",\"com.example.b\"]}"

            let decoder = JSONDecoder()
            let request = try decoder.decode(
                GetProductsRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.productIds == ["com.example.a", "com.example.b"])
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = GetProductsRequest(productIds: ["test1", "test2", "test3"])

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(GetProductsRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = GetProductsRequest(productIds: ["test"])

            await Task.detached {
                #expect(request.productIds.count == 1)
            }.value
        }
    }

    // MARK: - PurchaseRequest Tests

    @Suite("PurchaseRequest")
    struct PurchaseRequestTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let request = PurchaseRequest(productId: "com.example.premium")

            let encoder = JSONEncoder()
            let data = try encoder.encode(request)
            let json = String(data: data, encoding: .utf8)!

            #expect(json == "{\"productId\":\"com.example.premium\"}")
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = "{\"productId\":\"com.example.coins\"}"

            let decoder = JSONDecoder()
            let request = try decoder.decode(
                PurchaseRequest.self,
                from: json.data(using: .utf8)!
            )

            #expect(request.productId == "com.example.coins")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = PurchaseRequest(productId: "com.example.test")

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(PurchaseRequest.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let request = PurchaseRequest(productId: "test")

            await Task.detached {
                #expect(request.productId == "test")
            }.value
        }
    }

    // MARK: - GetProductsResponse Tests

    @Suite("GetProductsResponse")
    struct GetProductsResponseTests {
        @Test("Encodes correctly")
        func encodesCorrectly() throws {
            let response = GetProductsResponse(products: [
                ProductInfo(
                    id: "com.example.a",
                    displayName: "Product A",
                    displayPrice: "$1.99",
                    type: .consumable
                ),
            ])

            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"products\""))
            #expect(json.contains("\"id\":\"com.example.a\""))
        }

        @Test("Encodes empty products list")
        func encodesEmptyProducts() throws {
            let response = GetProductsResponse(products: [])

            let encoder = JSONEncoder()
            let data = try encoder.encode(response)
            let json = String(data: data, encoding: .utf8)!

            #expect(json == "{\"products\":[]}")
        }

        @Test("Decodes from JSON")
        func decodesFromJSON() throws {
            let json = """
            {
                "products": [
                    {
                        "id": "com.example.test",
                        "displayName": "Test",
                        "displayPrice": "$0.99",
                        "type": "consumable",
                        "description": null
                    }
                ]
            }
            """

            let decoder = JSONDecoder()
            let response = try decoder.decode(
                GetProductsResponse.self,
                from: json.data(using: .utf8)!
            )

            #expect(response.products.count == 1)
            #expect(response.products[0].id == "com.example.test")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = GetProductsResponse(products: [
                ProductInfo(
                    id: "id1",
                    displayName: "Name1",
                    displayPrice: "$1.99",
                    type: .nonConsumable
                ),
                ProductInfo(
                    id: "id2",
                    displayName: "Name2",
                    displayPrice: "$2.99",
                    type: .autoRenewable
                ),
            ])

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(GetProductsResponse.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let response = GetProductsResponse(products: [])

            await Task.detached {
                #expect(response.products.isEmpty)
            }.value
        }
    }

    // MARK: - RestoreResult Tests

    @Suite("RestoreResult")
    struct RestoreResultTests {
        @Test("Successful restore encodes correctly")
        func successfulRestoreEncodes() throws {
            let result = RestoreResult(restoredProductIds: ["com.example.a", "com.example.b"])

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(result)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":true"))
            #expect(json.contains("\"restoredProductIds\":[\"com.example.a\",\"com.example.b\"]"))
            #expect(!json.contains("\"error\"") || json.contains("\"error\":null"))
        }

        @Test("Failed restore encodes correctly")
        func failedRestoreEncodes() throws {
            let result = RestoreResult(error: "Unable to restore")

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(result)
            let json = String(data: data, encoding: .utf8)!

            #expect(json.contains("\"success\":false"))
            #expect(json.contains("\"error\":\"Unable to restore\""))
        }

        @Test("Decodes successful restore from JSON")
        func decodesSuccessfulFromJSON() throws {
            let json = """
            {
                "success": true,
                "restoredProductIds": ["id1", "id2"],
                "error": null
            }
            """

            let decoder = JSONDecoder()
            let result = try decoder.decode(
                RestoreResult.self,
                from: json.data(using: .utf8)!
            )

            #expect(result.success == true)
            #expect(result.restoredProductIds == ["id1", "id2"])
            #expect(result.error == nil)
        }

        @Test("Decodes failed restore from JSON")
        func decodesFailedFromJSON() throws {
            let json = """
            {
                "success": false,
                "restoredProductIds": null,
                "error": "Network error"
            }
            """

            let decoder = JSONDecoder()
            let result = try decoder.decode(
                RestoreResult.self,
                from: json.data(using: .utf8)!
            )

            #expect(result.success == false)
            #expect(result.restoredProductIds == nil)
            #expect(result.error == "Network error")
        }

        @Test("Round-trips through encoding and decoding")
        func roundTrips() throws {
            let original = RestoreResult(restoredProductIds: ["test1", "test2"])

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(RestoreResult.self, from: data)

            #expect(decoded == original)
        }

        @Test("Is Sendable")
        func isSendable() async {
            let result = RestoreResult(restoredProductIds: ["test"])

            await Task.detached {
                #expect(result.success == true)
            }.value
        }

        @Test("Convenience initializer for success sets correct values")
        func successInitializerSetsCorrectValues() {
            let result = RestoreResult(restoredProductIds: ["id1", "id2"])

            #expect(result.success == true)
            #expect(result.restoredProductIds == ["id1", "id2"])
            #expect(result.error == nil)
        }

        @Test("Convenience initializer for failure sets correct values")
        func failureInitializerSetsCorrectValues() {
            let result = RestoreResult(error: "Failed")

            #expect(result.success == false)
            #expect(result.restoredProductIds == nil)
            #expect(result.error == "Failed")
        }

        @Test("Empty restore is successful")
        func emptyRestoreIsSuccessful() throws {
            let result = RestoreResult(restoredProductIds: [])

            #expect(result.success == true)
            #expect(result.restoredProductIds?.isEmpty == true)
            #expect(result.error == nil)
        }
    }
}
