import fs from 'node:fs';
import type { PWAConfig } from './schema.js';

export function loadConfig(configPath: string): PWAConfig {
  const raw = fs.readFileSync(configPath, 'utf-8');
  return JSON.parse(raw) as PWAConfig;
}
