/**
 * StoreKit Module API
 *
 * Provides StoreKit 2 integration for in-app purchases.
 *
 * @module ios/storeKit
 */

import { bridge } from '../bridge';

/**
 * Product types matching StoreKit Product.ProductType.
 */
export type ProductType =
  | 'consumable'
  | 'nonConsumable'
  | 'autoRenewable'
  | 'nonRenewable';

/**
 * Product information.
 */
export interface ProductInfo {
  /** Product identifier */
  id: string;
  /** Localized display name */
  displayName: string;
  /** Localized description */
  description: string;
  /** Localized price string (e.g., '$0.99') */
  displayPrice: string;
  /** Price in decimal */
  price: number;
  /** Currency code (e.g., 'USD') */
  currencyCode: string;
  /** Product type */
  type: ProductType;
}

/**
 * Purchase result.
 */
export interface PurchaseResult {
  /** Whether the purchase was successful */
  success: boolean;
  /** Transaction ID if successful */
  transactionId?: string;
  /** Error message if failed */
  error?: string;
  /** Whether the purchase is pending (e.g., parental approval) */
  pending?: boolean;
  /** Whether the user cancelled the purchase */
  cancelled?: boolean;
}

/**
 * Entitlement info for owned products.
 */
export interface EntitlementInfo {
  /** Array of owned product IDs */
  ownedProductIds: string[];
}

/**
 * StoreKit module for in-app purchases.
 *
 * @example
 * ```typescript
 * import { ios } from '@eddmann/pwa-kit-sdk';
 *
 * // Get available products
 * const products = await ios.storeKit.getProducts(['premium', 'coins_100']);
 * for (const product of products) {
 *   console.log(`${product.displayName}: ${product.displayPrice}`);
 * }
 *
 * // Purchase a product
 * const result = await ios.storeKit.purchase('premium');
 * if (result.success) {
 *   console.log('Purchase successful:', result.transactionId);
 * }
 *
 * // Restore purchases
 * await ios.storeKit.restore();
 *
 * // Check entitlements
 * const entitlements = await ios.storeKit.getEntitlements();
 * const hasPremium = entitlements.ownedProductIds.includes('premium');
 * ```
 */
export const storeKit = {
  /**
   * Fetches product information from the App Store.
   *
   * @param productIds - Array of product identifiers to fetch
   * @returns Array of product information
   */
  async getProducts(productIds: string[]): Promise<ProductInfo[]> {
    const result = await bridge.call<{ products: ProductInfo[] }>(
      'iap',
      'getProducts',
      { productIds }
    );
    return result.products;
  },

  /**
   * Initiates a purchase for the given product.
   *
   * @param productId - Product identifier to purchase
   * @returns Purchase result
   */
  async purchase(productId: string): Promise<PurchaseResult> {
    return bridge.call<PurchaseResult>('iap', 'purchase', { productId });
  },

  /**
   * Restores previously purchased products.
   *
   * This syncs the user's purchase history with the App Store and
   * updates local entitlements.
   */
  async restore(): Promise<void> {
    await bridge.call('iap', 'restore');
  },

  /**
   * Gets the current entitlements (owned products).
   *
   * @returns Entitlement information with owned product IDs
   */
  async getEntitlements(): Promise<EntitlementInfo> {
    return bridge.call<EntitlementInfo>('iap', 'getEntitlements');
  },

  /**
   * Checks if a specific product is owned.
   *
   * @param productId - Product identifier to check
   * @returns Whether the product is owned
   */
  async isOwned(productId: string): Promise<boolean> {
    const entitlements = await this.getEntitlements();
    return entitlements.ownedProductIds.includes(productId);
  },
};
