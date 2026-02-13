import type { DisplayMode, Feature, Orientation } from '../utils/validation.js';

export interface PWAConfig {
  version: number;
  app: {
    name: string;
    bundleId: string;
    startUrl: string;
  };
  origins: {
    allowed: string[];
    auth: string[];
    external: string[];
  };
  features: Record<Feature, boolean>;
  appearance: {
    displayMode: DisplayMode;
    pullToRefresh: boolean;
    statusBarStyle: string;
    orientationLock: Orientation;
    backgroundColor: string;
    themeColor: string;
  };
  notifications: {
    provider: string;
  };
}
