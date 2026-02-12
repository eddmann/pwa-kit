import { logger } from '../utils/logger.js';
import type { WebManifest } from './parse.js';

function extractBaseUrl(url: string): string {
  return url.replace(/(https?:\/\/[^/]+).*/, '$1');
}

function makeAbsoluteUrl(href: string, baseUrl: string): string {
  if (href.startsWith('http')) return href;
  if (href.startsWith('/')) return `${baseUrl}${href}`;
  return `${baseUrl}/${href}`;
}

async function tryFetchManifest(url: string): Promise<WebManifest | null> {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(10_000) });
    if (!response.ok) return null;
    return (await response.json()) as WebManifest;
  } catch {
    return null;
  }
}

function extractManifestHref(html: string): string | null {
  // Match <link rel="manifest" href="..."> in any attribute order
  let match = html.match(/<link\b[^>]*\brel=["']manifest["'][^>]*\bhref=["']([^"']+)["']/i);
  if (!match) {
    // Try reverse order: href before rel
    match = html.match(/<link\b[^>]*\bhref=["']([^"']+)["'][^>]*\brel=["']manifest["']/i);
  }
  return match?.[1] ?? null;
}

export interface FetchManifestResult {
  manifest: WebManifest;
  baseUrl: string;
}

export async function fetchManifest(startUrl: string): Promise<FetchManifestResult | null> {
  logger.info('Fetching web manifest...');

  const baseUrl = extractBaseUrl(startUrl);

  // First: parse <link rel="manifest"> from the start URL HTML
  try {
    const response = await fetch(startUrl, { signal: AbortSignal.timeout(10_000) });
    if (response.ok) {
      const html = await response.text();
      const href = extractManifestHref(html);

      if (href) {
        const manifestUrl = makeAbsoluteUrl(href, baseUrl);
        logger.info(`Found <link rel="manifest"> pointing to: ${manifestUrl}`);
        const manifest = await tryFetchManifest(manifestUrl);
        if (manifest) {
          logger.success(`Found manifest at: ${manifestUrl}`);
          return { manifest, baseUrl };
        }
      }
    }
  } catch {
    // Continue to fallbacks
  }

  // Fallback: try well-known paths
  for (const path of ['/manifest.json', '/manifest.webmanifest', '/site.webmanifest']) {
    const url = `${baseUrl}${path}`;
    const manifest = await tryFetchManifest(url);
    if (manifest) {
      logger.success(`Found manifest at: ${url}`);
      return { manifest, baseUrl };
    }
  }

  logger.warn('Could not find web manifest');
  return null;
}
