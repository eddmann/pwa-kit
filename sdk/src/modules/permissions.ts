/**
 * Permissions Module API
 *
 * Provides permission querying and requesting.
 * Aligned with the Web Permissions API.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
 *
 * @module permissions
 */

import { bridge } from '../bridge';

/**
 * Permission names supported by the native bridge.
 */
export type PermissionName = 'camera' | 'geolocation' | 'microphone';

/**
 * Permission states aligned with Web Permissions API.
 */
export type PermissionState = 'granted' | 'denied' | 'prompt';

/**
 * Permission status object aligned with Web Permissions API.
 */
export interface PermissionStatus {
  /** The current permission state */
  state: PermissionState;
  /** The permission name */
  name: PermissionName;
}

/**
 * Permission descriptor for querying/requesting.
 */
export interface PermissionDescriptor {
  /** The permission name to query */
  name: PermissionName;
}

/**
 * Internal result types from native calls.
 */
interface NativePermissionResult {
  state: 'notDetermined' | 'denied' | 'granted' | 'authorized' | 'restricted';
}

interface NativeLocationResult {
  state:
    | 'notDetermined'
    | 'denied'
    | 'granted'
    | 'authorizedAlways'
    | 'authorizedWhenInUse'
    | 'restricted';
}

/**
 * Maps native permission states to Web API states.
 */
function mapCameraState(state: NativePermissionResult['state']): PermissionState {
  switch (state) {
    case 'granted':
    case 'authorized':
      return 'granted';
    case 'denied':
    case 'restricted':
      return 'denied';
    case 'notDetermined':
    default:
      return 'prompt';
  }
}

/**
 * Maps native location states to Web API states.
 */
function mapLocationState(state: NativeLocationResult['state']): PermissionState {
  switch (state) {
    case 'granted':
    case 'authorizedAlways':
    case 'authorizedWhenInUse':
      return 'granted';
    case 'denied':
    case 'restricted':
      return 'denied';
    case 'notDetermined':
    default:
      return 'prompt';
  }
}

/**
 * Maps permission name to native module name.
 */
function getModuleName(name: PermissionName): string {
  switch (name) {
    case 'camera':
    case 'microphone':
      return 'cameraPermission';
    case 'geolocation':
      return 'locationPermission';
  }
}

/**
 * Permissions module for querying and requesting device permissions.
 * Aligned with the Web Permissions API (navigator.permissions).
 *
 * Note: Actual media/location access uses web APIs (getUserMedia, Geolocation).
 * This module provides native permission management for pre-prompting and
 * checking status before using web APIs.
 *
 * @example
 * ```typescript
 * import { permissions } from '@eddmann/pwa-kit-sdk';
 *
 * // Query permission state
 * const status = await permissions.query({ name: 'camera' });
 * console.log('Camera permission:', status.state);
 *
 * // Request permission if needed
 * if (status.state === 'prompt') {
 *   const newStatus = await permissions.request({ name: 'camera' });
 *   console.log('New state:', newStatus.state);
 * }
 *
 * // Query geolocation
 * const geoStatus = await permissions.query({ name: 'geolocation' });
 * ```
 */
export const permissions = {
  /**
   * Queries the current permission state.
   *
   * Aligned with navigator.permissions.query().
   *
   * @param descriptor - Permission descriptor with name
   * @returns Permission status with current state
   */
  async query(descriptor: PermissionDescriptor): Promise<PermissionStatus> {
    const moduleName = getModuleName(descriptor.name);

    if (descriptor.name === 'geolocation') {
      const result = await bridge.call<NativeLocationResult>(
        moduleName,
        'checkPermission'
      );
      return {
        name: descriptor.name,
        state: mapLocationState(result.state),
      };
    }

    const result = await bridge.call<NativePermissionResult>(
      moduleName,
      'checkPermission'
    );
    return {
      name: descriptor.name,
      state: mapCameraState(result.state),
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
  async request(descriptor: PermissionDescriptor): Promise<PermissionStatus> {
    const moduleName = getModuleName(descriptor.name);

    if (descriptor.name === 'geolocation') {
      const result = await bridge.call<NativeLocationResult>(
        moduleName,
        'requestPermission'
      );
      return {
        name: descriptor.name,
        state: mapLocationState(result.state),
      };
    }

    const result = await bridge.call<NativePermissionResult>(
      moduleName,
      'requestPermission'
    );
    return {
      name: descriptor.name,
      state: mapCameraState(result.state),
    };
  },
};
