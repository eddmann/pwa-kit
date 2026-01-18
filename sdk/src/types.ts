/**
 * PWAKit JavaScript SDK Type Definitions
 *
 * Type definitions for the JavaScript-to-Swift bridge communication protocol.
 */

/**
 * A message from JavaScript to the native bridge.
 *
 * Each message contains:
 * - A unique request ID for response correlation
 * - The target module name
 * - The action to perform
 * - An optional payload with action-specific data
 *
 * @example
 * ```typescript
 * const message: BridgeMessage = {
 *   id: '550e8400-e29b-41d4-a716-446655440000',
 *   module: 'haptics',
 *   action: 'impact',
 *   payload: { style: 'medium' }
 * };
 * ```
 */
export interface BridgeMessage {
  /** Unique request ID for response correlation (typically a UUID string) */
  id: string;
  /** The target module name (e.g., 'platform', 'haptics', 'notifications') */
  module: string;
  /** The action to perform on the module (e.g., 'getInfo', 'impact', 'subscribe') */
  action: string;
  /** Optional payload with action-specific data */
  payload?: unknown;
}

/**
 * A response from the native bridge to JavaScript.
 *
 * Each response contains:
 * - The request ID matching the original BridgeMessage
 * - A success flag indicating whether the action succeeded
 * - Optional data on success
 * - Optional error message on failure
 *
 * @example
 * ```typescript
 * // Success response
 * const successResponse: BridgeResponse = {
 *   id: '550e8400-e29b-41d4-a716-446655440000',
 *   success: true,
 *   data: { triggered: true }
 * };
 *
 * // Error response
 * const errorResponse: BridgeResponse = {
 *   id: '550e8400-e29b-41d4-a716-446655440000',
 *   success: false,
 *   error: 'Unknown action: invalid'
 * };
 * ```
 */
export interface BridgeResponse<T = unknown> {
  /** Request ID that correlates to the original BridgeMessage */
  id: string;
  /** Whether the action completed successfully */
  success: boolean;
  /** Result data on success (structure depends on module and action) */
  data?: T;
  /** Error message on failure */
  error?: string;
}

/**
 * An event from native code to JavaScript.
 *
 * Events are unsolicited notifications from the native layer, not correlated
 * with a request ID. Used for push notifications, lifecycle changes, etc.
 *
 * @example
 * ```typescript
 * const pushEvent: BridgeEvent = {
 *   type: 'push',
 *   data: {
 *     title: 'New Message',
 *     body: 'You have a new message',
 *     userInfo: { messageId: '123' }
 *   }
 * };
 * ```
 */
export interface BridgeEvent<T = unknown> {
  /** Event type identifier (e.g., 'push', 'lifecycle', 'deeplink') */
  type: string;
  /** Event payload data (structure depends on event type) */
  data?: T;
}

/**
 * Options for bridge call operations.
 */
export interface BridgeCallOptions {
  /** Timeout in milliseconds (default: 30000) */
  timeout?: number;
}

/**
 * Callback storage entry for pending requests.
 */
export interface PendingCallback<T = unknown> {
  /** Resolve function for the promise */
  resolve: (value: T) => void;
  /** Reject function for the promise */
  reject: (error: Error) => void;
  /** Timeout handle for cleanup */
  timeoutId?: ReturnType<typeof setTimeout>;
}

/**
 * Configuration options for the PWABridge.
 */
export interface BridgeConfig {
  /** Default timeout for all calls in milliseconds (default: 30000) */
  defaultTimeout?: number;
  /** Enable debug logging (default: false) */
  debug?: boolean;
}

/**
 * The global pwakit object interface that Swift injects into the webview.
 * This is the low-level interface - use PWABridge class for a better API.
 */
export interface PWAKitGlobal {
  /** Send a message to native (internal use) */
  postMessage: (message: string) => void;
  /** Callbacks storage for pending requests (internal use) */
  _callbacks: Record<string, PendingCallback>;
  /** Handle response from native (called by Swift) */
  _handleResponse: (response: BridgeResponse) => void;
  /** Handle event from native (called by Swift) */
  _handleEvent: (event: BridgeEvent) => void;
}

/**
 * Extended Window interface with pwakit global.
 */
declare global {
  interface Window {
    /** The PWAKit bridge object injected by Swift */
    pwakit?: PWAKitGlobal;
    /** WebKit message handlers (iOS WKWebView) */
    webkit?: {
      messageHandlers?: {
        pwakit?: {
          postMessage: (message: string) => void;
        };
      };
    };
  }
}

/**
 * Bridge error class for typed error handling.
 */
export class BridgeError extends Error {
  /** The request ID this error relates to */
  public readonly requestId?: string;
  /** The module that caused the error */
  public readonly module?: string;
  /** The action that caused the error */
  public readonly action?: string;

  constructor(
    message: string,
    options?: {
      requestId?: string;
      module?: string;
      action?: string;
    }
  ) {
    super(message);
    this.name = 'BridgeError';
    this.requestId = options?.requestId;
    this.module = options?.module;
    this.action = options?.action;
  }
}

/**
 * Error thrown when a bridge call times out.
 */
export class BridgeTimeoutError extends BridgeError {
  /** The timeout duration in milliseconds */
  public readonly timeout: number;

  constructor(
    message: string,
    timeout: number,
    options?: {
      requestId?: string;
      module?: string;
      action?: string;
    }
  ) {
    super(message, options);
    this.name = 'BridgeTimeoutError';
    this.timeout = timeout;
  }
}

/**
 * Error thrown when the bridge is not available.
 */
export class BridgeUnavailableError extends BridgeError {
  constructor(message: string = 'PWAKit bridge is not available') {
    super(message);
    this.name = 'BridgeUnavailableError';
  }
}
