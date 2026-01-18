/**
 * PWAKit Kitchen Sink Example
 *
 * Comprehensive testing app demonstrating ALL PWAKit SDK features.
 * This example covers every available API for testing and reference.
 */

// ============================================================================
// SDK Module Destructuring
// ============================================================================

const {
  // Detection utilities
  isNative,
  getPlatformInfo,
  // Web API-aligned modules
  push,
  badging,
  clipboard,
  share,
  permissions,
  // Enhanced APIs
  haptics,
  print,
  platform,
  // iOS-specific namespace
  ios,
} = PWAKit;

// ============================================================================
// Console Logger
// ============================================================================

const consoleLog = {
  entries: [],
  maxEntries: 100,

  add(level, message, data) {
    const timestamp = new Date().toLocaleTimeString();
    const entry = { timestamp, level, message, data };
    this.entries.unshift(entry);
    if (this.entries.length > this.maxEntries) {
      this.entries.pop();
    }
    this.render();
    console.log(`[${level.toUpperCase()}]`, message, data !== undefined ? data : '');
  },

  info(message, data) { this.add('info', message, data); },
  success(message, data) { this.add('success', message, data); },
  error(message, data) { this.add('error', message, data); },
  warn(message, data) { this.add('warn', message, data); },

  clear() {
    this.entries = [];
    this.render();
  },

  render() {
    const content = document.getElementById('console-content');
    if (!content) return;

    if (this.entries.length === 0) {
      content.innerHTML = '<div class="ios-empty-state">No logs yet</div>';
      return;
    }

    content.innerHTML = this.entries.map(entry => {
      const dataStr = entry.data !== undefined ? `\n${JSON.stringify(entry.data, null, 2)}` : '';
      return `<div class="ios-log-entry ${entry.level}">
        <span class="ios-log-timestamp">${entry.timestamp}</span>
        ${escapeHtml(entry.message)}${escapeHtml(dataStr)}
      </div>`;
    }).join('');
  }
};

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// ============================================================================
// Loading State Helper
// ============================================================================

/**
 * Wraps an async function with loading state management.
 * Shows a spinner on the button while the operation is in progress.
 * @param {HTMLElement} button - The button element
 * @param {Function} asyncFn - The async function to execute
 */
async function withLoading(button, asyncFn) {
  if (!button || button.classList.contains('loading')) return;

  try {
    button.classList.add('loading');
    button.disabled = true;
    await asyncFn();
  } finally {
    button.classList.remove('loading');
    button.disabled = false;
  }
}

// ============================================================================
// Bridge Detection & Setup
// ============================================================================

function detectBridge() {
  if (isNative) {
    consoleLog.success('Native bridge detected (using PWAKit SDK)');
  } else {
    consoleLog.warn('Running in web browser (native features not available)');
  }
  updateStatusBadge();
}

function updateStatusBadge() {
  const badge = document.getElementById('platform-badge');
  if (badge) {
    badge.textContent = isNative ? 'Native App' : 'Web Browser';
    badge.className = `ios-status-pill ${isNative ? 'native' : 'web'}`;
  }
}

function displayPlatformDetection() {
  const container = document.getElementById('platform-detection');
  if (!container) return;

  const info = getPlatformInfo();

  container.innerHTML = `
    <div class="ios-detection-grid">
      <div class="ios-detection-item ${info.isNative ? 'active' : ''}">
        <div class="ios-detection-label">isNative</div>
        <div class="ios-detection-value">${info.isNative}</div>
      </div>
      <div class="ios-detection-item ${info.hasMessageHandlers ? 'active' : ''}">
        <div class="ios-detection-label">messageHandlers</div>
        <div class="ios-detection-value">${info.hasMessageHandlers}</div>
      </div>
      <div class="ios-detection-item ${info.hasPWAKitUserAgent ? 'active' : ''}">
        <div class="ios-detection-label">PWAKit UA</div>
        <div class="ios-detection-value">${info.hasPWAKitUserAgent}</div>
      </div>
      <div class="ios-detection-item">
        <div class="ios-detection-label">platform</div>
        <div class="ios-detection-value">${info.platform}</div>
      </div>
    </div>
    <div class="ios-user-agent">UA: ${escapeHtml(info.userAgent || 'N/A')}</div>
  `;
}

// ============================================================================
// Module Test Functions
// ============================================================================

// Platform Module
async function testPlatformInfo() {
  try {
    consoleLog.info('Getting platform info...');
    const info = await platform.getInfo();
    consoleLog.success('Platform info:', info);
    showResult('platform-result', info, true);
  } catch (err) {
    consoleLog.error('Platform info failed:', err.message);
    showResult('platform-result', err.message, false);
  }
}

// Haptics Module
async function testHapticsImpact(style) {
  try {
    consoleLog.info(`Triggering impact haptic: ${style}`);
    await haptics.impact(style);
    consoleLog.success(`Impact haptic (${style}) triggered`);
  } catch (err) {
    consoleLog.error('Haptic impact failed:', err.message);
  }
}

async function testHapticsNotification(type) {
  try {
    consoleLog.info(`Triggering notification haptic: ${type}`);
    await haptics.notification(type);
    consoleLog.success(`Notification haptic (${type}) triggered`);
  } catch (err) {
    consoleLog.error('Haptic notification failed:', err.message);
  }
}

async function testHapticsSelection() {
  try {
    consoleLog.info('Triggering selection haptic');
    await haptics.selection();
    consoleLog.success('Selection haptic triggered');
  } catch (err) {
    consoleLog.error('Haptic selection failed:', err.message);
  }
}

// Push Notifications Module
async function testNotificationsSubscribe() {
  try {
    consoleLog.info('Subscribing to push notifications...');
    const subscription = await push.subscribe();
    consoleLog.success('Push subscription:', subscription);
    showResult('notifications-result', subscription, true);
  } catch (err) {
    consoleLog.error('Push subscription failed:', err.message);
    showResult('notifications-result', err.message, false);
  }
}

async function testNotificationsGetToken() {
  try {
    consoleLog.info('Getting push subscription...');
    const subscription = await push.getSubscription();
    if (subscription) {
      consoleLog.success('Push subscription:', subscription);
      showResult('notifications-result', subscription, true);
    } else {
      consoleLog.info('No active push subscription');
      showResult('notifications-result', { token: null, message: 'No active subscription' }, true);
    }
  } catch (err) {
    consoleLog.error('Get subscription failed:', err.message);
    showResult('notifications-result', err.message, false);
  }
}

async function testNotificationsPermission() {
  try {
    consoleLog.info('Getting push permission state...');
    const state = await push.permissionState();
    consoleLog.success('Permission state:', state);
    showResult('notifications-result', { state }, true);
  } catch (err) {
    consoleLog.error('Get permission failed:', err.message);
    showResult('notifications-result', err.message, false);
  }
}

async function testNotificationsSetBadge() {
  const count = parseInt(document.getElementById('badge-count').value || '0', 10);
  try {
    consoleLog.info(`Setting badge count: ${count}`);
    await badging.setAppBadge(count);
    consoleLog.success(`Badge set to ${count}`);
  } catch (err) {
    consoleLog.error('Set badge failed:', err.message);
  }
}

async function testNotificationsClearBadge() {
  try {
    consoleLog.info('Clearing badge...');
    await badging.clearAppBadge();
    consoleLog.success('Badge cleared');
  } catch (err) {
    consoleLog.error('Clear badge failed:', err.message);
  }
}

// Push Event Listener
let pushListenerActive = false;
let pushUnsubscribe = null;

function togglePushListener() {
  const btn = document.getElementById('push-listen-btn');
  const eventsDiv = document.getElementById('push-events');

  if (pushListenerActive) {
    // Stop listening
    if (pushUnsubscribe) {
      pushUnsubscribe();
      pushUnsubscribe = null;
    }
    pushListenerActive = false;
    btn.textContent = 'Start Listening';
    btn.classList.remove('ios-btn-success');
    btn.classList.add('ios-btn-secondary');
    eventsDiv.classList.add('hidden');
    consoleLog.info('Stopped listening for push events');
  } else {
    // Start listening
    pushListenerActive = true;
    btn.textContent = 'Listening...';
    btn.classList.remove('ios-btn-secondary');
    btn.classList.add('ios-btn-success');
    eventsDiv.classList.remove('hidden');
    eventsDiv.textContent = 'Waiting for push events...';

    // Set up listener using the bridge event pattern
    const handler = (event) => {
      const data = event.detail;
      const timestamp = new Date().toLocaleTimeString();
      eventsDiv.innerHTML = `<strong>${timestamp}</strong> - Push received!\n${JSON.stringify(data, null, 2)}`;
      consoleLog.success('Push event received', data);
    };
    window.addEventListener('pwa:push', handler);

    pushUnsubscribe = () => {
      window.removeEventListener('pwa:push', handler);
    };

    consoleLog.info('Listening for push events (pwa:push)');
  }
}

// Share Module
async function testShareCanShare() {
  try {
    consoleLog.info('Checking if sharing is available...');
    const available = await share.canShare();
    consoleLog.success('Can share:', available);
    showResult('share-result', { available }, true);
  } catch (err) {
    consoleLog.error('canShare check failed:', err.message);
    showResult('share-result', err.message, false);
  }
}

async function testShare() {
  const title = document.getElementById('share-title').value || 'PWAKit Test';
  const text = document.getElementById('share-text').value || 'Testing the share feature';
  const url = document.getElementById('share-url').value || 'https://github.com';

  try {
    consoleLog.info('Opening share sheet...');
    const result = await share.share({ title, text, url });
    consoleLog.success('Share result:', result);
    showResult('share-result', result, true);
  } catch (err) {
    consoleLog.error('Share failed:', err.message);
    showResult('share-result', err.message, false);
  }
}

async function testShareFile() {
  // Create a small sample PNG image (1x1 pixel red)
  const samplePngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==';

  try {
    consoleLog.info('Sharing sample image file...');
    const result = await share.share({
      title: 'Sample Image',
      files: [{
        name: 'sample-image.png',
        type: 'image/png',
        data: samplePngBase64
      }]
    });
    consoleLog.success('Share file result:', result);
    showResult('share-result', result, true);
  } catch (err) {
    consoleLog.error('Share file failed:', err.message);
    showResult('share-result', err.message, false);
  }
}

async function testShareTextFile() {
  const textContent = 'Hello from PWAKit!\n\nThis is a sample text file shared via the native share sheet.';
  const textBase64 = btoa(textContent);

  try {
    consoleLog.info('Sharing text file...');
    const result = await share.share({
      title: 'Sample Document',
      files: [{
        name: 'pwakit-sample.txt',
        type: 'text/plain',
        data: textBase64
      }]
    });
    consoleLog.success('Share text file result:', result);
    showResult('share-result', result, true);
  } catch (err) {
    consoleLog.error('Share text file failed:', err.message);
    showResult('share-result', err.message, false);
  }
}

// Biometrics Module (iOS-specific)
async function testBiometricsAvailable() {
  try {
    consoleLog.info('Checking biometrics availability...');
    const result = await ios.biometrics.isAvailable();
    consoleLog.success('Biometrics availability:', result);
    showResult('biometrics-result', result, true);
  } catch (err) {
    consoleLog.error('Biometrics check failed:', err.message);
    showResult('biometrics-result', err.message, false);
  }
}

async function testBiometricsAuth() {
  const reason = document.getElementById('biometrics-reason').value || 'Authenticate to continue';
  try {
    consoleLog.info('Requesting biometric authentication...');
    const result = await ios.biometrics.authenticate(reason);
    consoleLog.success('Biometrics auth result:', result);
    showResult('biometrics-result', result, result.success);
  } catch (err) {
    consoleLog.error('Biometrics auth failed:', err.message);
    showResult('biometrics-result', err.message, false);
  }
}

// Secure Storage Module (iOS-specific)
async function testStorageSet() {
  const key = document.getElementById('storage-key').value;
  const value = document.getElementById('storage-value').value;
  if (!key || !value) {
    consoleLog.warn('Please enter both key and value');
    return;
  }
  try {
    consoleLog.info(`Storing value for key: ${key}`);
    await ios.secureStorage.set(key, value);
    consoleLog.success(`Value stored for key: ${key}`);
    showResult('storage-result', { success: true, key }, true);
  } catch (err) {
    consoleLog.error('Storage set failed:', err.message);
    showResult('storage-result', err.message, false);
  }
}

async function testStorageGet() {
  const key = document.getElementById('storage-key').value;
  if (!key) {
    consoleLog.warn('Please enter a key');
    return;
  }
  try {
    consoleLog.info(`Getting value for key: ${key}`);
    const value = await ios.secureStorage.get(key);
    consoleLog.success('Storage get result:', { key, value });
    showResult('storage-result', { key, value }, true);
  } catch (err) {
    consoleLog.error('Storage get failed:', err.message);
    showResult('storage-result', err.message, false);
  }
}

async function testStorageDelete() {
  const key = document.getElementById('storage-key').value;
  if (!key) {
    consoleLog.warn('Please enter a key');
    return;
  }
  try {
    consoleLog.info(`Deleting key: ${key}`);
    await ios.secureStorage.delete(key);
    consoleLog.success(`Key deleted: ${key}`);
    showResult('storage-result', { success: true, deleted: key }, true);
  } catch (err) {
    consoleLog.error('Storage delete failed:', err.message);
    showResult('storage-result', err.message, false);
  }
}

async function testStorageHas() {
  const key = document.getElementById('storage-key').value;
  if (!key) {
    consoleLog.warn('Please enter a key');
    return;
  }
  try {
    consoleLog.info(`Checking if key exists: ${key}`);
    const exists = await ios.secureStorage.has(key);
    consoleLog.success(`Key "${key}" exists: ${exists}`);
    showResult('storage-result', { key, exists }, true);
  } catch (err) {
    consoleLog.error('Storage exists check failed:', err.message);
    showResult('storage-result', err.message, false);
  }
}

// Print Module
async function testPrint() {
  try {
    consoleLog.info('Opening print dialog...');
    const result = await print.print();
    consoleLog.success('Print result:', result);
  } catch (err) {
    consoleLog.error('Print failed:', err.message);
  }
}

// App Module (iOS-specific)
async function testAppReview() {
  try {
    consoleLog.info('Requesting app review...');
    const result = await ios.app.requestReview();
    consoleLog.success('Review request result:', result);
    showResult('app-result', result, true);
  } catch (err) {
    consoleLog.error('Review request failed:', err.message);
    showResult('app-result', err.message, false);
  }
}

async function testAppOpenSettings() {
  try {
    consoleLog.info('Opening app settings...');
    await ios.app.openSettings();
    consoleLog.success('Settings opened');
  } catch (err) {
    consoleLog.error('Open settings failed:', err.message);
  }
}

async function testAppVersion() {
  try {
    consoleLog.info('Getting app version...');
    const result = await ios.app.getVersion();
    consoleLog.success('App version:', result);
    showResult('app-result', result, true);
  } catch (err) {
    consoleLog.error('Get version failed:', err.message);
    showResult('app-result', err.message, false);
  }
}

// Clipboard Module
async function testClipboardWrite() {
  const text = document.getElementById('clipboard-text').value;
  if (!text) {
    consoleLog.warn('Please enter text to copy');
    return;
  }
  try {
    consoleLog.info('Copying to clipboard...');
    await clipboard.writeText(text);
    consoleLog.success('Text copied to clipboard');
    showResult('clipboard-result', { success: true, copied: text }, true);
  } catch (err) {
    consoleLog.error('Clipboard write failed:', err.message);
    showResult('clipboard-result', err.message, false);
  }
}

async function testClipboardRead() {
  try {
    consoleLog.info('Reading from clipboard...');
    const text = await clipboard.readText();
    consoleLog.success('Clipboard content:', { text });
    showResult('clipboard-result', { text }, true);
  } catch (err) {
    consoleLog.error('Clipboard read failed:', err.message);
    showResult('clipboard-result', err.message, false);
  }
}

// IAP Module (iOS-specific - StoreKit)
async function testIAPGetProducts() {
  const idsInput = document.getElementById('iap-product-ids').value;
  const productIds = idsInput ? idsInput.split(',').map(s => s.trim()) : ['premium', 'coins_100'];
  try {
    consoleLog.info('Fetching products:', productIds);
    const products = await ios.storeKit.getProducts(productIds);
    consoleLog.success('Products:', products);
    showResult('iap-result', { products }, true);
  } catch (err) {
    consoleLog.error('Get products failed:', err.message);
    showResult('iap-result', err.message, false);
  }
}

async function testIAPPurchase() {
  const productId = document.getElementById('iap-purchase-id').value || 'premium';
  try {
    consoleLog.info(`Purchasing product: ${productId}`);
    const result = await ios.storeKit.purchase(productId);
    consoleLog.success('Purchase result:', result);
    showResult('iap-result', result, result.success);
  } catch (err) {
    consoleLog.error('Purchase failed:', err.message);
    showResult('iap-result', err.message, false);
  }
}

async function testIAPRestore() {
  try {
    consoleLog.info('Restoring purchases...');
    await ios.storeKit.restore();
    consoleLog.success('Purchases restored');
    showResult('iap-result', { success: true, message: 'Purchases restored' }, true);
  } catch (err) {
    consoleLog.error('Restore failed:', err.message);
    showResult('iap-result', err.message, false);
  }
}

async function testIAPEntitlements() {
  try {
    consoleLog.info('Getting entitlements...');
    const result = await ios.storeKit.getEntitlements();
    consoleLog.success('Entitlements:', result);
    showResult('iap-result', result, true);
  } catch (err) {
    consoleLog.error('Get entitlements failed:', err.message);
    showResult('iap-result', err.message, false);
  }
}

async function testIAPIsOwned() {
  const productId = document.getElementById('iap-purchase-id').value || 'premium';
  try {
    consoleLog.info(`Checking if product is owned: ${productId}`);
    const isOwned = await ios.storeKit.isOwned(productId);
    const entitlements = await ios.storeKit.getEntitlements();
    consoleLog.success(`Product "${productId}" owned: ${isOwned}`);
    showResult('iap-result', { productId, isOwned, allOwned: entitlements.ownedProductIds }, true);
  } catch (err) {
    consoleLog.error('Check owned failed:', err.message);
    showResult('iap-result', err.message, false);
  }
}

// HealthKit Module (iOS-specific)
async function testHealthKitAvailable() {
  try {
    consoleLog.info('Checking HealthKit availability...');
    const result = await ios.healthKit.isAvailable();
    consoleLog.success('HealthKit availability:', result);
    showResult('healthkit-result', result, true);
  } catch (err) {
    consoleLog.error('HealthKit check failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

async function testHealthKitAuth() {
  try {
    consoleLog.info('Requesting HealthKit authorization...');
    const result = await ios.healthKit.requestAuthorization({
      read: ['stepCount', 'heartRate'],
      readWorkouts: true,
      readSleep: true
    });
    consoleLog.success('HealthKit auth result:', result);
    showResult('healthkit-result', result, result.success);
  } catch (err) {
    consoleLog.error('HealthKit auth failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

async function testHealthKitSteps() {
  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  try {
    consoleLog.info('Querying steps...');
    const samples = await ios.healthKit.querySteps({ startDate, endDate });
    consoleLog.success('Steps data:', samples);
    showResult('healthkit-result', { samples, count: samples.length }, true);
  } catch (err) {
    consoleLog.error('Query steps failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

async function testHealthKitHeartRate() {
  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  try {
    consoleLog.info('Querying heart rate...');
    const samples = await ios.healthKit.queryHeartRate({ startDate, endDate });
    consoleLog.success('Heart rate data:', samples);
    showResult('healthkit-result', { samples, count: samples.length }, true);
  } catch (err) {
    consoleLog.error('Query heart rate failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

async function testHealthKitWorkouts() {
  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  try {
    consoleLog.info('Querying workouts...');
    const workouts = await ios.healthKit.queryWorkouts({ startDate, endDate, limit: 10 });
    consoleLog.success('Workouts data:', workouts);
    showResult('healthkit-result', { workouts, count: workouts.length }, true);
  } catch (err) {
    consoleLog.error('Query workouts failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

async function testHealthKitSleep() {
  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  try {
    consoleLog.info('Querying sleep data...');
    const samples = await ios.healthKit.querySleep({ startDate, endDate });
    consoleLog.success('Sleep data:', samples);
    showResult('healthkit-result', { samples, count: samples.length }, true);
  } catch (err) {
    consoleLog.error('Query sleep failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

async function testHealthKitSaveWorkout() {
  const workoutType = document.getElementById('workout-type').value;
  const durationMinutes = parseInt(document.getElementById('workout-duration').value || '30', 10);
  const calories = parseInt(document.getElementById('workout-calories').value || '0', 10) || undefined;

  const endDate = new Date().toISOString();
  const startDate = new Date(Date.now() - durationMinutes * 60 * 1000).toISOString();

  try {
    consoleLog.info(`Saving ${workoutType} workout (${durationMinutes} minutes)...`);
    const result = await ios.healthKit.saveWorkout({
      workoutType,
      startDate,
      endDate,
      calories
    });
    consoleLog.success('Workout saved:', result);
    showResult('healthkit-result', { success: true, workoutType, durationMinutes }, true);
  } catch (err) {
    consoleLog.error('Save workout failed:', err.message);
    showResult('healthkit-result', err.message, false);
  }
}

// Permissions Module
async function testCameraPermissionCheck() {
  try {
    consoleLog.info('Checking camera permission...');
    const status = await permissions.query({ name: 'camera' });
    consoleLog.success('Camera permission:', status);
    showResult('permissions-result', status, true);
  } catch (err) {
    consoleLog.error('Camera permission check failed:', err.message);
    showResult('permissions-result', err.message, false);
  }
}

async function testCameraPermissionRequest() {
  try {
    consoleLog.info('Requesting camera permission...');
    const status = await permissions.request({ name: 'camera' });
    consoleLog.success('Camera permission result:', status);
    showResult('permissions-result', status, true);
  } catch (err) {
    consoleLog.error('Camera permission request failed:', err.message);
    showResult('permissions-result', err.message, false);
  }
}

async function testLocationPermissionCheck() {
  try {
    consoleLog.info('Checking location permission...');
    const status = await permissions.query({ name: 'geolocation' });
    consoleLog.success('Location permission:', status);
    showResult('permissions-result', status, true);
  } catch (err) {
    consoleLog.error('Location permission check failed:', err.message);
    showResult('permissions-result', err.message, false);
  }
}

async function testLocationPermissionRequest() {
  try {
    consoleLog.info('Requesting location permission...');
    const status = await permissions.request({ name: 'geolocation' });
    consoleLog.success('Location permission result:', status);
    showResult('permissions-result', status, true);
  } catch (err) {
    consoleLog.error('Location permission request failed:', err.message);
    showResult('permissions-result', err.message, false);
  }
}

// ============================================================================
// UI Helpers
// ============================================================================

function showResult(elementId, data, success) {
  const el = document.getElementById(elementId);
  if (!el) return;

  el.className = `ios-result ${success ? 'success' : 'error'}`;
  el.textContent = typeof data === 'string' ? data : JSON.stringify(data, null, 2);
  el.classList.remove('hidden');
}

function toggleModule(cellElement) {
  cellElement.classList.toggle('expanded');
}

function toggleConsole() {
  const consoleEl = document.getElementById('console');
  consoleEl.classList.toggle('expanded');
}

function clearConsole() {
  consoleLog.clear();
}

// ============================================================================
// Event Listeners for Native Events
// ============================================================================

function setupEventListeners() {
  // Push notification events
  window.addEventListener('pwa:push', (event) => {
    consoleLog.info('Push notification received', event.detail);
  });

  // Lifecycle events
  window.addEventListener('pwa:lifecycle', (event) => {
    consoleLog.info('Lifecycle event', event.detail);
  });

  // App visibility
  document.addEventListener('visibilitychange', () => {
    consoleLog.info('Visibility changed:', document.visibilityState);
  });
}

// ============================================================================
// Initialization
// ============================================================================

function init() {
  // Detect bridge
  detectBridge();

  // Display platform detection info
  displayPlatformDetection();

  // Setup event listeners
  setupEventListeners();

  // Initial log
  consoleLog.info('PWAKit Kitchen Sink initialized (using SDK)');

  const info = getPlatformInfo();
  consoleLog.info(`Running on: ${info.platform} (native: ${info.isNative})`);
}

// Run on DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
