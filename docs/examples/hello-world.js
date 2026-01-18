/**
 * Hello World Module - JavaScript Usage Example
 *
 * This file demonstrates how to call the HelloWorldModule
 * from JavaScript using the PWAKit SDK bridge.
 */

import { bridge, isNative } from '@eddmann/pwa-kit-sdk';

// ============================================================================
// Basic Usage
// ============================================================================

/**
 * Example: Simple greeting
 */
async function greetUser() {
  if (!isNative) {
    console.log('Running in browser - native features unavailable');
    return;
  }

  // Call the greet action with a name
  const result = await bridge.call('helloWorld', 'greet', {
    name: 'Developer',
  });

  console.log(result.message); // "Hello, Developer!"
  console.log(result.timestamp); // 1704067200.0 (Unix timestamp)
}

/**
 * Example: Greeting with default name
 */
async function greetDefault() {
  // Omit the name for default "World" greeting
  const result = await bridge.call('helloWorld', 'greet');

  console.log(result.message); // "Hello, World!"
}

/**
 * Example: Echo text back
 */
async function echoText() {
  const result = await bridge.call('helloWorld', 'echo', {
    text: 'Testing the bridge!',
  });

  console.log(result.echoed); // "Testing the bridge!"
  console.log(result.length); // 19
}

/**
 * Example: Add two numbers
 */
async function addNumbers() {
  const result = await bridge.call('helloWorld', 'add', {
    a: 5,
    b: 3,
  });

  console.log(result.result); // 8
}

// ============================================================================
// Error Handling
// ============================================================================

/**
 * Example: Handle missing required field
 */
async function handleMissingField() {
  try {
    // This will throw because 'text' is required for echo
    await bridge.call('helloWorld', 'echo', {});
  } catch (error) {
    console.error('Error:', error.message);
    // "Invalid payload: Missing required 'text' field"
  }
}

/**
 * Example: Handle unknown action
 */
async function handleUnknownAction() {
  try {
    await bridge.call('helloWorld', 'unknownAction', {});
  } catch (error) {
    console.error('Error:', error.message);
    // "Unknown action: unknownAction"
  }
}

/**
 * Example: Handle unknown module
 */
async function handleUnknownModule() {
  try {
    await bridge.call('nonExistentModule', 'action', {});
  } catch (error) {
    console.error('Error:', error.message);
    // "Unknown module: nonExistentModule"
  }
}

// ============================================================================
// Practical Usage Pattern
// ============================================================================

/**
 * Complete example with proper error handling and fallbacks
 */
async function demonstrateModule() {
  // Check if we're in the native app
  if (!isNative) {
    console.log('HelloWorld module requires the native PWAKit app');
    return;
  }

  try {
    // Greet the user
    const greeting = await bridge.call('helloWorld', 'greet', {
      name: 'PWAKit User',
    });
    console.log(`✓ Greeting: ${greeting.message}`);

    // Echo some text
    const echo = await bridge.call('helloWorld', 'echo', {
      text: 'Bridge communication works!',
    });
    console.log(`✓ Echo: "${echo.echoed}" (${echo.length} chars)`);

    // Perform a calculation
    const sum = await bridge.call('helloWorld', 'add', { a: 10, b: 20 });
    console.log(`✓ Math: 10 + 20 = ${sum.result}`);

    console.log('\nAll HelloWorld module tests passed!');
  } catch (error) {
    console.error('HelloWorld module error:', error.message);
  }
}

// Run the demonstration
demonstrateModule();
