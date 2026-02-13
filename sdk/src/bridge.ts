/**
 * PWAKit JavaScript Bridge Client
 *
 * A TypeScript client for communicating with the native iOS bridge.
 * Provides a unified, Promise-based API with request ID tracking and timeout handling.
 */

import type {
  BridgeMessage,
  BridgeResponse,
  BridgeEvent,
  BridgeCallOptions,
  BridgeConfig,
  PendingCallback,
} from './types';

import {
  BridgeError,
  BridgeTimeoutError,
  BridgeUnavailableError,
} from './types';

/** Default timeout for bridge calls in milliseconds */
const DEFAULT_TIMEOUT = 30000;

/**
 * Generates a UUID v4 string for request IDs.
 */
function generateUUID(): string {
  // Use crypto.randomUUID if available (modern browsers)
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }

  // Fallback implementation
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * PWABridge provides a unified, Promise-based API for communicating with
 * the native iOS bridge.
 *
 * @example
 * ```typescript
 * import { PWABridge } from '@pwa-kit/sdk';
 *
 * const bridge = new PWABridge();
 *
 * // Check if running in native app
 * if (bridge.isAvailable()) {
 *   // Call a native module
 *   const info = await bridge.call<PlatformInfo>('platform', 'getInfo');
 *   console.log(info.platform, info.version);
 *
 *   // Trigger haptic feedback
 *   await bridge.call('haptics', 'impact', { style: 'medium' });
 * }
 * ```
 */
export class PWABridge {
  /** Pending callbacks indexed by request ID */
  private callbacks: Map<string, PendingCallback> = new Map();

  /** Default timeout for all calls */
  private defaultTimeout: number;

  /** Debug mode flag */
  private debug: boolean;

  /** Whether the bridge has been initialized */
  private initialized = false;

  /**
   * Creates a new PWABridge instance.
   *
   * @param config - Optional configuration options
   */
  constructor(config: BridgeConfig = {}) {
    this.defaultTimeout = config.defaultTimeout ?? DEFAULT_TIMEOUT;
    this.debug = config.debug ?? false;

    // Auto-initialize if the bridge is available
    if (this.isAvailable()) {
      this.initialize();
    }
  }

  /**
   * Checks if the native bridge is available.
   *
   * Returns true when running inside the PWAKit native app wrapper,
   * false when running in a regular browser.
   *
   * @returns true if the bridge is available
   */
  public isAvailable(): boolean {
    return (
      typeof window !== 'undefined' &&
      typeof window.webkit?.messageHandlers?.pwakit?.postMessage === 'function'
    );
  }

  /**
   * Initializes the bridge by setting up response and event handlers.
   *
   * This is called automatically when creating a PWABridge instance if the
   * bridge is available. You can also call it manually if the bridge becomes
   * available later (e.g., after async loading).
   */
  public initialize(): void {
    if (this.initialized) {
      return;
    }

    if (typeof window === 'undefined') {
      return;
    }

    // Create or extend the global pwakit object
    window.pwakit = window.pwakit ?? {
      postMessage: (message: string) => {
        window.webkit?.messageHandlers?.pwakit?.postMessage(message);
      },
      _callbacks: {},
      _handleResponse: () => {},
      _handleEvent: () => {},
    };

    // Set up the response handler
    window.pwakit._handleResponse = (response: BridgeResponse) => {
      this.handleResponse(response);
    };

    // Set up the event handler
    window.pwakit._handleEvent = (event: BridgeEvent) => {
      this.handleEvent(event);
    };

    this.initialized = true;
    this.log('Bridge initialized');
  }

  /**
   * Calls a native module action with the given payload.
   *
   * @typeParam T - The expected response data type
   * @param module - The target module name (e.g., 'platform', 'haptics')
   * @param action - The action to perform (e.g., 'getInfo', 'impact')
   * @param payload - Optional action-specific payload data
   * @param options - Optional call options (timeout, etc.)
   * @returns A promise that resolves with the response data
   * @throws {BridgeUnavailableError} If the bridge is not available
   * @throws {BridgeTimeoutError} If the call times out
   * @throws {BridgeError} If the native module returns an error
   *
   * @example
   * ```typescript
   * // Get platform info
   * const info = await bridge.call<PlatformInfo>('platform', 'getInfo');
   *
   * // Trigger haptic feedback with payload
   * await bridge.call('haptics', 'impact', { style: 'heavy' });
   *
   * // Call with custom timeout
   * const result = await bridge.call('storage', 'get', { key: 'data' }, { timeout: 5000 });
   * ```
   */
  public call<T = unknown>(
    module: string,
    action: string,
    payload?: unknown,
    options?: BridgeCallOptions
  ): Promise<T> {
    return new Promise((resolve, reject) => {
      // Check if bridge is available
      if (!this.isAvailable()) {
        reject(new BridgeUnavailableError());
        return;
      }

      // Ensure bridge is initialized
      if (!this.initialized) {
        this.initialize();
      }

      // Generate a unique request ID
      const id = generateUUID();

      // Create the message
      const message: BridgeMessage = {
        id,
        module,
        action,
        payload,
      };

      // Set up timeout
      const timeout = options?.timeout ?? this.defaultTimeout;
      const timeoutId = setTimeout(() => {
        // Clean up the callback
        this.callbacks.delete(id);

        // Reject with timeout error
        reject(
          new BridgeTimeoutError(
            `Bridge call to ${module}.${action} timed out after ${timeout}ms`,
            timeout,
            { requestId: id, module, action }
          )
        );
      }, timeout);

      // Store the callback
      this.callbacks.set(id, {
        resolve: resolve as (value: unknown) => void,
        reject,
        timeoutId,
      });

      // Send the message
      this.log(`Sending: ${module}.${action}`, payload);
      try {
        window.webkit?.messageHandlers?.pwakit?.postMessage(
          JSON.stringify(message)
        );
      } catch (error) {
        // Clean up on send error
        clearTimeout(timeoutId);
        this.callbacks.delete(id);
        reject(
          new BridgeError(
            `Failed to send message: ${error instanceof Error ? error.message : String(error)}`,
            { requestId: id, module, action }
          )
        );
      }
    });
  }

  /**
   * Handles a response from the native bridge.
   *
   * @param response - The response from native
   * @internal
   */
  private handleResponse(response: BridgeResponse): void {
    this.log('Received response:', response);

    const callback = this.callbacks.get(response.id);
    if (!callback) {
      this.log(`No callback found for request ID: ${response.id}`);
      return;
    }

    // Clean up
    if (callback.timeoutId) {
      clearTimeout(callback.timeoutId);
    }
    this.callbacks.delete(response.id);

    // Resolve or reject
    if (response.success) {
      callback.resolve(response.data);
    } else {
      callback.reject(
        new BridgeError(response.error ?? 'Unknown error', {
          requestId: response.id,
        })
      );
    }
  }

  /**
   * Handles an event from the native bridge.
   *
   * Dispatches a CustomEvent on the window with the event type prefixed by 'pwa:'.
   *
   * @param event - The event from native
   * @internal
   */
  private handleEvent(event: BridgeEvent): void {
    this.log('Received event:', event);

    // Dispatch as a CustomEvent on window
    if (typeof window !== 'undefined' && typeof CustomEvent !== 'undefined') {
      const customEvent = new CustomEvent(`pwa:${event.type}`, {
        detail: event.data,
        bubbles: true,
        cancelable: false,
      });
      window.dispatchEvent(customEvent);
    }
  }

  /**
   * Registers a listener for native events.
   *
   * This is a convenience wrapper around window.addEventListener for
   * PWAKit events. Event types are automatically prefixed with 'pwa:'.
   *
   * @typeParam T - The expected event data type
   * @param type - The event type (without 'pwa:' prefix)
   * @param listener - The event listener callback
   * @returns A function to remove the listener
   *
   * @example
   * ```typescript
   * // Listen for push notifications
   * const unsubscribe = bridge.on<PushData>('push', (data) => {
   *   console.log('Push received:', data.title);
   * });
   *
   * // Later: remove the listener
   * unsubscribe();
   * ```
   */
  public on<T = unknown>(
    type: string,
    listener: (data: T) => void
  ): () => void {
    const eventType = `pwa:${type}`;
    const handler = (event: Event) => {
      listener((event as CustomEvent<T>).detail);
    };

    window.addEventListener(eventType, handler);

    // Return unsubscribe function
    return () => {
      window.removeEventListener(eventType, handler);
    };
  }

  /**
   * Registers a one-time listener for a native event.
   *
   * The listener is automatically removed after being called once.
   *
   * @typeParam T - The expected event data type
   * @param type - The event type (without 'pwa:' prefix)
   * @param listener - The event listener callback
   *
   * @example
   * ```typescript
   * // Listen for a single push notification
   * bridge.once<PushData>('push', (data) => {
   *   console.log('Got first push:', data.title);
   * });
   * ```
   */
  public once<T = unknown>(
    type: string,
    listener: (data: T) => void
  ): void {
    const unsubscribe = this.on<T>(type, (data) => {
      unsubscribe();
      listener(data);
    });
  }

  /**
   * Logs a debug message if debug mode is enabled.
   *
   * @param args - Arguments to log
   * @internal
   */
  private log(...args: unknown[]): void {
    if (this.debug) {
      console.log('[PWABridge]', ...args);
    }
  }
}

// Export a default singleton instance
export const bridge = new PWABridge();

// Re-export types
export type {
  BridgeMessage,
  BridgeResponse,
  BridgeEvent,
  BridgeCallOptions,
  BridgeConfig,
} from './types';

export {
  BridgeError,
  BridgeTimeoutError,
  BridgeUnavailableError,
} from './types';
