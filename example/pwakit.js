var PWAKit = (function (exports) {
  'use strict';

  var __defProp = Object.defineProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };

  // src/types.ts
  var BridgeError = class extends Error {
    constructor(message, options) {
      super(message);
      this.name = "BridgeError";
      this.requestId = options?.requestId;
      this.module = options?.module;
      this.action = options?.action;
    }
  };
  var BridgeTimeoutError = class extends BridgeError {
    constructor(message, timeout, options) {
      super(message, options);
      this.name = "BridgeTimeoutError";
      this.timeout = timeout;
    }
  };
  var BridgeUnavailableError = class extends BridgeError {
    constructor(message = "PWAKit bridge is not available") {
      super(message);
      this.name = "BridgeUnavailableError";
    }
  };

  // src/bridge.ts
  var DEFAULT_TIMEOUT = 3e4;
  function generateUUID() {
    if (typeof crypto !== "undefined" && crypto.randomUUID) {
      return crypto.randomUUID();
    }
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0;
      const v = c === "x" ? r : r & 3 | 8;
      return v.toString(16);
    });
  }
  var PWABridge = class {
    /**
     * Creates a new PWABridge instance.
     *
     * @param config - Optional configuration options
     */
    constructor(config = {}) {
      /** Pending callbacks indexed by request ID */
      this.callbacks = /* @__PURE__ */ new Map();
      /** Whether the bridge has been initialized */
      this.initialized = false;
      this.defaultTimeout = config.defaultTimeout ?? DEFAULT_TIMEOUT;
      this.debug = config.debug ?? false;
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
    isAvailable() {
      return typeof window !== "undefined" && typeof window.webkit?.messageHandlers?.pwakit?.postMessage === "function";
    }
    /**
     * Initializes the bridge by setting up response and event handlers.
     *
     * This is called automatically when creating a PWABridge instance if the
     * bridge is available. You can also call it manually if the bridge becomes
     * available later (e.g., after async loading).
     */
    initialize() {
      if (this.initialized) {
        return;
      }
      if (typeof window === "undefined") {
        return;
      }
      window.pwakit = window.pwakit ?? {
        postMessage: (message) => {
          window.webkit?.messageHandlers?.pwakit?.postMessage(message);
        },
        _callbacks: {},
        _handleResponse: () => {
        },
        _handleEvent: () => {
        }
      };
      window.pwakit._handleResponse = (response) => {
        this.handleResponse(response);
      };
      window.pwakit._handleEvent = (event) => {
        this.handleEvent(event);
      };
      this.initialized = true;
      this.log("Bridge initialized");
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
    call(module, action, payload, options) {
      return new Promise((resolve, reject) => {
        if (!this.isAvailable()) {
          reject(new BridgeUnavailableError());
          return;
        }
        if (!this.initialized) {
          this.initialize();
        }
        const id = generateUUID();
        const message = {
          id,
          module,
          action,
          payload
        };
        const timeout = options?.timeout ?? this.defaultTimeout;
        const timeoutId = setTimeout(() => {
          this.callbacks.delete(id);
          reject(
            new BridgeTimeoutError(
              `Bridge call to ${module}.${action} timed out after ${timeout}ms`,
              timeout,
              { requestId: id, module, action }
            )
          );
        }, timeout);
        this.callbacks.set(id, {
          resolve,
          reject,
          timeoutId
        });
        this.log(`Sending: ${module}.${action}`, payload);
        try {
          window.webkit?.messageHandlers?.pwakit?.postMessage(
            JSON.stringify(message)
          );
        } catch (error) {
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
    handleResponse(response) {
      this.log("Received response:", response);
      const callback = this.callbacks.get(response.id);
      if (!callback) {
        this.log(`No callback found for request ID: ${response.id}`);
        return;
      }
      if (callback.timeoutId) {
        clearTimeout(callback.timeoutId);
      }
      this.callbacks.delete(response.id);
      if (response.success) {
        callback.resolve(response.data);
      } else {
        callback.reject(
          new BridgeError(response.error ?? "Unknown error", {
            requestId: response.id
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
    handleEvent(event) {
      this.log("Received event:", event);
      if (typeof window !== "undefined" && typeof CustomEvent !== "undefined") {
        const customEvent = new CustomEvent(`pwa:${event.type}`, {
          detail: event.data,
          bubbles: true,
          cancelable: false
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
    on(type, listener) {
      const eventType = `pwa:${type}`;
      const handler = (event) => {
        listener(event.detail);
      };
      window.addEventListener(eventType, handler);
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
    once(type, listener) {
      const unsubscribe = this.on(type, (data) => {
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
    log(...args) {
      if (this.debug) {
        console.log("[PWABridge]", ...args);
      }
    }
  };
  var bridge = new PWABridge();

  // src/modules/push.ts
  function mapPermissionState(state) {
    switch (state) {
      case "granted":
        return "granted";
      case "denied":
        return "denied";
      case "not_determined":
      default:
        return "prompt";
    }
  }
  var push = {
    /**
     * Subscribes to push notifications.
     *
     * Requests notification permission if needed, then registers for
     * remote notifications with APNs.
     *
     * Aligned with PushManager.subscribe().
     *
     * @returns Push subscription with device token
     * @throws Error if subscription fails
     */
    async subscribe() {
      const result = await bridge.call(
        "notifications",
        "subscribe"
      );
      if (!result.success || !result.token) {
        throw new Error(result.error ?? "Failed to subscribe to push notifications");
      }
      return {
        token: result.token,
        endpoint: `apns://${result.token}`
      };
    },
    /**
     * Gets the current push subscription if one exists.
     *
     * Aligned with PushManager.getSubscription().
     *
     * @returns The current subscription, or null if not subscribed
     */
    async getSubscription() {
      const result = await bridge.call(
        "notifications",
        "getToken"
      );
      if (!result.token) {
        return null;
      }
      return {
        token: result.token,
        endpoint: `apns://${result.token}`
      };
    },
    /**
     * Requests notification permission without registering for push.
     *
     * Use this when you only need local notifications and don't need
     * an APNs device token. Aligned with Notification.requestPermission().
     *
     * @returns Permission state after the request: 'granted', 'denied', or 'prompt'
     */
    async requestPermission() {
      const result = await bridge.call(
        "notifications",
        "requestPermission"
      );
      return mapPermissionState(result.state);
    },
    /**
     * Gets the current push notification permission state.
     *
     * Aligned with PushManager.permissionState().
     *
     * @returns Permission state: 'granted', 'denied', or 'prompt'
     */
    async permissionState() {
      const result = await bridge.call(
        "notifications",
        "getPermissionState"
      );
      return mapPermissionState(result.state);
    }
  };

  // src/modules/badging.ts
  var badging = {
    /**
     * Sets the app icon badge.
     *
     * Aligned with navigator.setAppBadge().
     *
     * @param count - Badge count. If omitted or 0, shows a plain indicator.
     *                On iOS, 0 clears the badge.
     */
    async setAppBadge(count) {
      await bridge.call("notifications", "setBadge", { count: count ?? 0 });
    },
    /**
     * Clears the app icon badge.
     *
     * Aligned with navigator.clearAppBadge().
     */
    async clearAppBadge() {
      await bridge.call("notifications", "setBadge", { count: 0 });
    }
  };

  // src/modules/vibration.ts
  var vibration = {
    /**
     * Triggers device vibration.
     *
     * Aligned with navigator.vibrate().
     *
     * On iOS, this triggers haptic feedback since the Vibration API
     * is not supported. Single values trigger an impact haptic,
     * patterns trigger multiple haptics with the specified timing.
     *
     * @param pattern - Vibration duration in ms, or array of durations
     *                  for vibrate/pause pattern. Pass 0 or [] to stop.
     * @returns true if vibration was triggered, false otherwise
     */
    vibrate(pattern) {
      if (pattern === 0 || Array.isArray(pattern) && pattern.length === 0) {
        return true;
      }
      const durations = Array.isArray(pattern) ? pattern : pattern !== void 0 ? [pattern] : [200];
      const vibrations = durations.filter((_, i) => i % 2 === 0).filter((d) => d > 0);
      for (let i = 0; i < vibrations.length; i++) {
        const delay = durations.slice(0, i * 2).reduce((a, b) => a + b, 0);
        setTimeout(() => {
          bridge.call("haptics", "impact", { style: "medium" }).catch(() => {
          });
        }, delay);
      }
      return true;
    }
  };

  // src/modules/clipboard.ts
  var clipboard = {
    /**
     * Writes text to the clipboard.
     *
     * Aligned with navigator.clipboard.writeText().
     *
     * @param text - Text to copy to clipboard
     */
    async writeText(text) {
      await bridge.call("clipboard", "write", { text });
    },
    /**
     * Reads text from the clipboard.
     *
     * Aligned with navigator.clipboard.readText().
     *
     * Note: On iOS 16+, this may trigger a paste permission prompt.
     *
     * @returns The clipboard text, or null if empty
     */
    async readText() {
      const result = await bridge.call("clipboard", "read");
      return result.text;
    }
  };

  // src/modules/share.ts
  var share = {
    /**
     * Presents the native share sheet with the given content.
     *
     * @param options - Content to share
     * @returns Result indicating if the share was completed
     */
    async share(options) {
      return bridge.call("share", "share", options);
    },
    /**
     * Checks if sharing is available.
     *
     * Always returns true on iOS native, but useful for graceful degradation
     * when running in regular browsers.
     *
     * @returns Whether the share API is available
     */
    async canShare() {
      const result = await bridge.call(
        "share",
        "canShare"
      );
      return result.available;
    }
  };

  // src/modules/permissions.ts
  function mapCameraState(state) {
    switch (state) {
      case "granted":
      case "authorized":
        return "granted";
      case "denied":
      case "restricted":
        return "denied";
      case "notDetermined":
      default:
        return "prompt";
    }
  }
  function mapLocationState(state) {
    switch (state) {
      case "granted":
      case "authorizedAlways":
      case "authorizedWhenInUse":
        return "granted";
      case "denied":
      case "restricted":
        return "denied";
      case "notDetermined":
      default:
        return "prompt";
    }
  }
  function getModuleName(name) {
    switch (name) {
      case "camera":
      case "microphone":
        return "cameraPermission";
      case "geolocation":
        return "locationPermission";
    }
  }
  var permissions = {
    /**
     * Queries the current permission state.
     *
     * Aligned with navigator.permissions.query().
     *
     * @param descriptor - Permission descriptor with name
     * @returns Permission status with current state
     */
    async query(descriptor) {
      const moduleName = getModuleName(descriptor.name);
      if (descriptor.name === "geolocation") {
        const result2 = await bridge.call(
          moduleName,
          "checkPermission"
        );
        return {
          name: descriptor.name,
          state: mapLocationState(result2.state)
        };
      }
      const result = await bridge.call(
        moduleName,
        "checkPermission"
      );
      return {
        name: descriptor.name,
        state: mapCameraState(result.state)
      };
    },
    /**
     * Requests a permission from the user.
     *
     * If permission has already been determined (granted or denied),
     * this returns the current state without showing a prompt.
     *
     * Note: This is an extension beyond the standard Permissions API,
     * which doesn't have a request method. Use this for pre-prompting
     * before calling web APIs.
     *
     * @param descriptor - Permission descriptor with name
     * @returns Permission status after request
     */
    async request(descriptor) {
      const moduleName = getModuleName(descriptor.name);
      if (descriptor.name === "geolocation") {
        const result2 = await bridge.call(
          moduleName,
          "requestPermission"
        );
        return {
          name: descriptor.name,
          state: mapLocationState(result2.state)
        };
      }
      const result = await bridge.call(
        moduleName,
        "requestPermission"
      );
      return {
        name: descriptor.name,
        state: mapCameraState(result.state)
      };
    }
  };

  // src/modules/haptics.ts
  var haptics = {
    /**
     * Triggers impact haptic feedback.
     *
     * Use for button taps, toggles, and physical interactions.
     *
     * @param style - The impact style (default: 'medium')
     */
    async impact(style = "medium") {
      await bridge.call("haptics", "impact", { style });
    },
    /**
     * Triggers notification haptic feedback.
     *
     * Use for success/warning/error outcomes.
     *
     * @param type - The notification type (default: 'success')
     */
    async notification(type = "success") {
      await bridge.call("haptics", "notification", { type });
    },
    /**
     * Triggers selection haptic feedback.
     *
     * Use for selection changes in pickers, sliders, etc.
     */
    async selection() {
      await bridge.call("haptics", "selection");
    }
  };

  // src/modules/print.ts
  var print = {
    /**
     * Prints the current webview content using AirPrint.
     *
     * Opens the native print dialog, allowing the user to select
     * a printer and configure print options.
     *
     * @returns Print result
     */
    async print() {
      return bridge.call("print", "print");
    }
  };

  // src/modules/platform.ts
  var platform = {
    /**
     * Gets platform and device information.
     *
     * @returns Platform information including OS version, app version, and device model
     */
    async getInfo() {
      return bridge.call("platform", "getInfo");
    }
  };

  // src/ios/index.ts
  var ios_exports = {};
  __export(ios_exports, {
    app: () => app,
    biometrics: () => biometrics,
    healthKit: () => healthKit,
    notifications: () => notifications,
    secureStorage: () => secureStorage,
    storeKit: () => storeKit
  });

  // src/ios/biometrics.ts
  var biometrics = {
    /**
     * Checks if biometric authentication is available.
     *
     * @returns Availability info including biometry type
     */
    async isAvailable() {
      return bridge.call("biometrics", "isAvailable");
    },
    /**
     * Prompts the user for biometric authentication.
     *
     * @param reason - Localized reason displayed to the user
     * @returns Authentication result
     */
    async authenticate(reason) {
      return bridge.call("biometrics", "authenticate", {
        reason
      });
    }
  };

  // src/ios/secureStorage.ts
  var secureStorage = {
    /**
     * Stores a value in the Keychain.
     *
     * @param key - Storage key
     * @param value - Value to store
     */
    async set(key, value) {
      await bridge.call("secureStorage", "set", { key, value });
    },
    /**
     * Retrieves a value from the Keychain.
     *
     * @param key - Storage key
     * @returns The stored value, or null if not found
     */
    async get(key) {
      const result = await bridge.call("secureStorage", "get", { key });
      return result.value;
    },
    /**
     * Deletes a value from the Keychain.
     *
     * @param key - Storage key to delete
     */
    async delete(key) {
      await bridge.call("secureStorage", "delete", { key });
    },
    /**
     * Checks if a key exists in the Keychain.
     *
     * @param key - Storage key to check
     * @returns Whether the key exists
     */
    async has(key) {
      const value = await this.get(key);
      return value !== null;
    }
  };

  // src/ios/healthKit.ts
  var healthKit = {
    /**
     * Checks if HealthKit is available on this device.
     *
     * @returns Availability result
     */
    async isAvailable() {
      return bridge.call("healthkit", "isAvailable");
    },
    /**
     * Requests HealthKit authorization for the specified data types.
     *
     * @param request - Authorization request specifying read/write types
     * @returns Authorization result
     */
    async requestAuthorization(request) {
      return bridge.call(
        "healthkit",
        "requestAuthorization",
        request
      );
    },
    /**
     * Queries step count data.
     *
     * @param options - Query options with date range
     * @returns Array of step count samples
     */
    async querySteps(options) {
      const result = await bridge.call(
        "healthkit",
        "querySteps",
        options
      );
      return result.samples;
    },
    /**
     * Queries heart rate data.
     *
     * @param options - Query options with date range
     * @returns Array of heart rate samples
     */
    async queryHeartRate(options) {
      const result = await bridge.call(
        "healthkit",
        "queryHeartRate",
        options
      );
      return result.samples;
    },
    /**
     * Queries workout data.
     *
     * @param options - Query options with date range and optional activity type filter
     * @returns Array of workout data
     */
    async queryWorkouts(options) {
      const result = await bridge.call(
        "healthkit",
        "queryWorkouts",
        options
      );
      return result.workouts;
    },
    /**
     * Queries sleep analysis data.
     *
     * @param options - Query options with date range
     * @returns Array of sleep samples
     */
    async querySleep(options) {
      const result = await bridge.call(
        "healthkit",
        "querySleep",
        options
      );
      return result.samples;
    },
    /**
     * Saves a workout to HealthKit.
     *
     * @param request - Workout save request
     * @returns Result with success status
     *
     * @example
     * ```typescript
     * await ios.healthKit.saveWorkout({
     *   workoutType: 'running',
     *   startDate: '2024-01-15T07:00:00Z',
     *   endDate: '2024-01-15T07:30:00Z',
     *   calories: 350,
     *   distance: 5000
     * });
     * ```
     */
    async saveWorkout(request) {
      return bridge.call("healthkit", "saveWorkout", request);
    }
  };

  // src/ios/storeKit.ts
  var storeKit = {
    /**
     * Fetches product information from the App Store.
     *
     * @param productIds - Array of product identifiers to fetch
     * @returns Array of product information
     */
    async getProducts(productIds) {
      const result = await bridge.call(
        "iap",
        "getProducts",
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
    async purchase(productId) {
      return bridge.call("iap", "purchase", { productId });
    },
    /**
     * Restores previously purchased products.
     *
     * This syncs the user's purchase history with the App Store and
     * updates local entitlements.
     */
    async restore() {
      await bridge.call("iap", "restore");
    },
    /**
     * Gets the current entitlements (owned products).
     *
     * @returns Entitlement information with owned product IDs
     */
    async getEntitlements() {
      return bridge.call("iap", "getEntitlements");
    },
    /**
     * Checks if a specific product is owned.
     *
     * @param productId - Product identifier to check
     * @returns Whether the product is owned
     */
    async isOwned(productId) {
      const entitlements = await this.getEntitlements();
      return entitlements.ownedProductIds.includes(productId);
    }
  };

  // src/ios/app.ts
  var app = {
    /**
     * Gets the app version and build number.
     *
     * @returns App version information
     */
    async getVersion() {
      return bridge.call("app", "getVersion");
    },
    /**
     * Requests the user to rate the app.
     *
     * Uses SKStoreReviewController.requestReview() which may or may not
     * show the rating dialog depending on Apple's rate limiting.
     *
     * @returns Whether the review dialog was presented
     */
    async requestReview() {
      return bridge.call("app", "requestReview");
    },
    /**
     * Opens the app's settings page in the Settings app.
     *
     * Useful for directing users to enable permissions they previously denied.
     */
    async openSettings() {
      await bridge.call("app", "openSettings");
    }
  };

  // src/ios/notifications.ts
  function serializeTrigger(trigger) {
    if (trigger.type === "date") {
      const date = trigger.date instanceof Date ? trigger.date.toISOString() : trigger.date;
      return { type: "date", date };
    }
    return { ...trigger };
  }
  var notifications = {
    /**
     * Schedules a local notification.
     *
     * @param options - The notification options including trigger.
     * @returns The scheduled notification ID.
     * @throws Error if scheduling fails.
     *
     * @example
     * ```typescript
     * // One-off notification in 5 minutes
     * await notifications.schedule({
     *   id: 'reminder-123',
     *   title: 'Time to take a break',
     *   body: 'You have been working for an hour',
     *   trigger: { type: 'timeInterval', seconds: 300 }
     * });
     *
     * // Repeating notification every hour (minimum 60 seconds for repeating)
     * await notifications.schedule({
     *   id: 'hourly',
     *   title: 'Hourly check-in',
     *   trigger: { type: 'timeInterval', seconds: 3600, repeats: true }
     * });
     * ```
     */
    async schedule(options) {
      const payload = {
        id: options.id,
        title: options.title,
        body: options.body,
        subtitle: options.subtitle,
        badge: options.badge,
        sound: options.sound,
        data: options.data,
        trigger: serializeTrigger(options.trigger)
      };
      const result = await bridge.call(
        "notifications",
        "schedule",
        payload
      );
      if (!result.success) {
        throw new Error("Failed to schedule notification");
      }
      return result.id;
    },
    /**
     * Cancels a scheduled notification by ID.
     *
     * @param id - The notification identifier to cancel.
     *
     * @example
     * ```typescript
     * await notifications.cancel('reminder-123');
     * ```
     */
    async cancel(id) {
      await bridge.call("notifications", "cancel", { id });
    },
    /**
     * Cancels all scheduled notifications.
     *
     * @example
     * ```typescript
     * await notifications.cancelAll();
     * ```
     */
    async cancelAll() {
      await bridge.call("notifications", "cancelAll");
    },
    /**
     * Gets all pending scheduled notifications.
     *
     * @returns Array of pending notification information.
     *
     * @example
     * ```typescript
     * const pending = await notifications.getPending();
     * for (const notification of pending) {
     *   console.log(`${notification.id}: ${notification.title}`);
     *   if (notification.nextTriggerDate) {
     *     console.log(`  Next: ${notification.nextTriggerDate}`);
     *   }
     * }
     * ```
     */
    async getPending() {
      const result = await bridge.call(
        "notifications",
        "getPending"
      );
      return result.notifications;
    }
  };

  // src/detection.ts
  function hasMessageHandlers() {
    if (typeof window === "undefined") {
      return false;
    }
    return typeof window.webkit?.messageHandlers?.pwakit?.postMessage === "function";
  }
  function hasPWAKitInUserAgent() {
    if (typeof navigator === "undefined") {
      return false;
    }
    return navigator.userAgent.includes("PWAKit");
  }
  function detectPlatform() {
    if (typeof navigator === "undefined") {
      return "unknown";
    }
    const userAgent = navigator.userAgent;
    const isIOSDevice = /iPad|iPhone|iPod/.test(userAgent) || navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1;
    if (hasMessageHandlers() || hasPWAKitInUserAgent()) {
      return "ios";
    }
    if (isIOSDevice) {
      return "ios";
    }
    if (typeof window !== "undefined" && typeof document !== "undefined") {
      return "browser";
    }
    return "unknown";
  }
  function getUserAgent() {
    if (typeof navigator === "undefined") {
      return null;
    }
    return navigator.userAgent;
  }
  function getPlatformInfo() {
    const messageHandlers = hasMessageHandlers();
    const pwaShellUA = hasPWAKitInUserAgent();
    return {
      isNative: messageHandlers || pwaShellUA,
      hasMessageHandlers: messageHandlers,
      hasPWAKitUserAgent: pwaShellUA,
      platform: detectPlatform(),
      userAgent: getUserAgent()
    };
  }
  var isNative = hasMessageHandlers() || hasPWAKitInUserAgent();
  var platformInfo = getPlatformInfo();

  exports.BridgeError = BridgeError;
  exports.BridgeTimeoutError = BridgeTimeoutError;
  exports.BridgeUnavailableError = BridgeUnavailableError;
  exports.PWABridge = PWABridge;
  exports.badging = badging;
  exports.bridge = bridge;
  exports.clipboard = clipboard;
  exports.detectPlatform = detectPlatform;
  exports.getPlatformInfo = getPlatformInfo;
  exports.getUserAgent = getUserAgent;
  exports.haptics = haptics;
  exports.hasMessageHandlers = hasMessageHandlers;
  exports.hasPWAKitInUserAgent = hasPWAKitInUserAgent;
  exports.ios = ios_exports;
  exports.isNative = isNative;
  exports.permissions = permissions;
  exports.platform = platform;
  exports.platformInfo = platformInfo;
  exports.print = print;
  exports.push = push;
  exports.share = share;
  exports.vibration = vibration;

  return exports;

})({});
//# sourceMappingURL=index.global.js.map
//# sourceMappingURL=index.global.js.map