import prompts from 'prompts';
import {
  isValidHttpsUrl,
  isValidBundleId,
  extractDomain,
  reverseDomain,
  ALL_FEATURES,
  type Feature,
} from '../utils/validation.js';
import { logger } from '../utils/logger.js';
import type { ManifestValues } from '../manifest/parse.js';

export interface WizardResult {
  startUrl: string;
  name: string;
  bundleId: string;
  allowedOrigins: string;
  features: Feature[];
}

export type ManifestFetcher = (url: string) => Promise<ManifestValues | null>;

export async function runWizard(getManifest?: ManifestFetcher): Promise<WizardResult | null> {
  console.log();
  console.log(logger.bold('+---------------------------------------------------------------+'));
  console.log(logger.bold('|                                                               |'));
  console.log(logger.bold(`|              ${logger.cyan('PWAKit - Interactive Setup Wizard')}              |`));
  console.log(logger.bold('|                                                               |'));
  console.log(logger.bold('|   This wizard will help you configure your PWA wrapper app.   |'));
  console.log(logger.bold('|                                                               |'));
  console.log(logger.bold('+---------------------------------------------------------------+'));
  console.log();

  // Step 1: Start URL
  console.log(logger.bold('Step 1 of 5: Start URL'));
  logger.info('The HTTPS URL of your PWA (must use HTTPS for security).');

  const { startUrl } = await prompts({
    type: 'text',
    name: 'startUrl',
    message: 'Enter start URL',
    validate: (v: string) => isValidHttpsUrl(v) || 'Must be a valid HTTPS URL (e.g., https://app.example.com)',
  });

  if (!startUrl) return null;

  const domain = extractDomain(startUrl);
  logger.success(`Start URL: ${startUrl}`);
  logger.info(`Detected domain: ${domain}`);
  console.log();

  // Fetch manifest for pre-filling subsequent steps
  let manifestValues: ManifestValues | null = null;
  if (getManifest) {
    manifestValues = await getManifest(startUrl);
  }

  // Step 2: App Name
  console.log(logger.bold('Step 2 of 5: App Name'));
  logger.info('This is the display name of your app (shown on home screen).');

  const { name } = await prompts({
    type: 'text',
    name: 'name',
    message: 'Enter app name',
    initial: manifestValues?.name || undefined,
    validate: (v: string) => v.trim().length > 0 || 'App name cannot be empty',
  });

  if (!name) return null;

  logger.success(`App name: ${name}`);
  console.log();

  // Step 3: Bundle ID
  console.log(logger.bold('Step 3 of 5: Bundle ID'));
  logger.info('Unique identifier for your app in reverse domain format.');

  const suggestedBundleId = reverseDomain(domain);

  const { bundleId } = await prompts({
    type: 'text',
    name: 'bundleId',
    message: 'Enter bundle ID',
    initial: suggestedBundleId,
    validate: (v: string) => isValidBundleId(v) || 'Use reverse domain format (e.g., com.example.myapp)',
  });

  if (!bundleId) return null;

  logger.success(`Bundle ID: ${bundleId}`);
  console.log();

  // Step 4: Allowed Origins
  console.log(logger.bold('Step 4 of 5: Allowed Origins'));
  logger.info(`Domains your app can navigate to (comma-separated for multiple).`);
  logger.info(`The domain from your start URL (${domain}) will always be included.`);

  const { allowedOrigins } = await prompts({
    type: 'text',
    name: 'allowedOrigins',
    message: 'Additional allowed domains (optional)',
    initial: '',
  });

  logger.success('Allowed origins configured');
  console.log();

  // Step 5: Features
  console.log(logger.bold('Step 5 of 5: Features'));
  logger.info('Enable native capabilities your PWA can access via the JavaScript bridge.');

  const featureChoices = ALL_FEATURES.map((f) => ({ title: f, value: f }));

  const { features } = await prompts({
    type: 'multiselect',
    name: 'features',
    message: 'Enable features',
    choices: featureChoices,
    hint: '- Space to select, Return to submit',
  });

  if (!features) return null;

  logger.success(`Features: ${features.length > 0 ? features.join(', ') : 'none'}`);
  console.log();

  return {
    startUrl,
    name,
    bundleId,
    allowedOrigins: allowedOrigins ?? '',
    features: features as Feature[],
  };
}
