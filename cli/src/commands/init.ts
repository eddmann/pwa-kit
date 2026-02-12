import { Command } from 'commander';
import fs from 'node:fs';
import path from 'node:path';
import { logger } from '../utils/logger.js';
import {
  isValidHttpsUrl,
  isValidBundleId,
  isValidHexColor,
  extractDomain,
  reverseDomain,
  VALID_ORIENTATIONS,
  VALID_DISPLAY_MODES,
  ALL_FEATURES,
  type Feature,
  type Orientation,
  type DisplayMode,
} from '../utils/validation.js';
import { projectPaths } from '../utils/paths.js';
import { detectProject } from '../template/detect.js';
import { downloadTemplate } from '../template/download.js';
import { fetchManifest } from '../manifest/fetch.js';
import { parseManifestValues, pickBestIcon } from '../manifest/parse.js';
import { downloadIcon } from '../manifest/icon.js';
import { generateConfig, writeConfig } from '../config/generate.js';
import { runSync } from '../sync/index.js';
import { runWizard } from '../wizard/prompts.js';

export const initCommand = new Command('init')
  .description('Create or configure a PWAKit project')
  .argument('[dir]', 'target directory', '.')
  .option('-u, --url <url>', 'start URL (HTTPS required)')
  .option('-n, --name <name>', 'app display name')
  .option('-b, --bundle-id <id>', 'bundle identifier')
  .option('-a, --allowed <origins>', 'additional allowed origins (comma-separated)')
  .option('--auth <origins>', 'auth origins (comma-separated)')
  .option('--bg-color <hex>', 'background color hex')
  .option('--theme-color <hex>', 'theme/accent color hex')
  .option('--orientation <lock>', 'orientation lock: any, portrait, landscape')
  .option('--display <mode>', 'display mode: standalone, fullscreen')
  .option('--features <list>', 'comma-separated enabled features')
  .option('-f, --force', 'overwrite existing config without prompting')
  .option('--template-version <version>', 'template version to download (e.g., v1.0.0)')
  .action(async (dir: string, opts: InitOptions) => {
    const targetDir = path.resolve(dir);

    // Detect or download project
    let projectRoot = detectProject(targetDir);

    if (!projectRoot) {
      logger.info('PWAKitApp.xcodeproj not found — downloading template...');
      const success = await downloadTemplate(targetDir, opts.templateVersion);
      if (!success) {
        logger.error('Failed to download template. Check your internet connection.');
        process.exit(1);
      }
      projectRoot = detectProject(targetDir);
      if (!projectRoot) {
        logger.error('Template downloaded but PWAKitApp.xcodeproj not found.');
        process.exit(1);
      }
    }

    const paths = projectPaths(projectRoot);

    // Check for existing config
    if (fs.existsSync(paths.configFile) && !opts.force) {
      const isInteractive = !opts.url && process.stdin.isTTY;
      if (!isInteractive) {
        logger.error(`Configuration file already exists: ${paths.configFile}`);
        logger.error('Use --force to overwrite');
        process.exit(1);
      }
    }

    // Determine interactive vs CLI mode
    const isInteractive = !opts.url && process.stdin.isTTY;

    let startUrl: string;
    let appName: string;
    let bundleId: string;
    let allowedOrigins: string[];
    let authOrigins: string[];
    let features: Feature[];
    let bgColor: string;
    let themeColor: string;
    let orientation: Orientation;
    let displayMode: DisplayMode;

    if (isInteractive) {
      // Fetch manifest first for pre-filling
      let manifestResult: Awaited<ReturnType<typeof fetchManifest>> = null;
      // We'll fetch after getting the URL in the wizard — but we need a two-pass approach:
      // First get URL from wizard step 1, then fetch manifest, then continue wizard.
      // For simplicity, run the full wizard first, then fetch manifest.

      const wizardResult = await runWizard(null);
      if (!wizardResult) {
        logger.info('Setup cancelled.');
        process.exit(0);
      }

      startUrl = wizardResult.startUrl;

      // Fetch manifest for colors/orientation/display/icon
      logger.info('Checking for web manifest...');
      manifestResult = await fetchManifest(startUrl);
      const manifestValues = manifestResult ? parseManifestValues(manifestResult.manifest) : null;

      if (manifestValues) {
        if (manifestValues.name) logger.info(`Manifest name: ${manifestValues.name}`);
        if (manifestValues.backgroundColor) logger.info(`Manifest background_color: ${manifestValues.backgroundColor}`);
        if (manifestValues.themeColor) logger.info(`Manifest theme_color: ${manifestValues.themeColor}`);
        if (manifestValues.orientation) logger.info(`Manifest orientation: ${manifestValues.orientation}`);
        if (manifestValues.display) logger.info(`Manifest display: ${manifestValues.display}`);
      }

      appName = wizardResult.name;
      bundleId = wizardResult.bundleId;
      features = wizardResult.features;

      const domain = extractDomain(startUrl);
      allowedOrigins = [domain];
      if (wizardResult.allowedOrigins) {
        allowedOrigins.push(
          ...wizardResult.allowedOrigins.split(',').map((s) => s.trim()).filter(Boolean),
        );
      }
      authOrigins = [];

      bgColor = manifestValues?.backgroundColor || '#FFFFFF';
      themeColor = manifestValues?.themeColor || '#007AFF';
      orientation = manifestValues?.orientation || 'any';
      displayMode = manifestValues?.display || 'standalone';

      // Download icon if manifest has one
      if (manifestResult) {
        const iconSrc = pickBestIcon(manifestResult.manifest);
        if (iconSrc) {
          await downloadIcon(iconSrc, manifestResult.baseUrl, paths.iconSource);
        }
      }
    } else {
      // Non-interactive mode
      if (!opts.url) {
        logger.error('Start URL is required (--url)');
        process.exit(1);
      }

      startUrl = opts.url;

      if (!isValidHttpsUrl(startUrl)) {
        logger.error(`Invalid start URL: ${startUrl}`);
        logger.error('URL must be a valid HTTPS URL (e.g., https://app.example.com)');
        process.exit(1);
      }

      if (opts.bundleId && !isValidBundleId(opts.bundleId)) {
        logger.error(`Invalid bundle ID format: ${opts.bundleId}`);
        process.exit(1);
      }

      if (opts.bgColor && !isValidHexColor(opts.bgColor)) {
        logger.error(`Invalid background color: ${opts.bgColor}`);
        process.exit(1);
      }

      if (opts.themeColor && !isValidHexColor(opts.themeColor)) {
        logger.error(`Invalid theme color: ${opts.themeColor}`);
        process.exit(1);
      }

      if (opts.orientation && !VALID_ORIENTATIONS.includes(opts.orientation as Orientation)) {
        logger.error(`Invalid orientation: ${opts.orientation}`);
        process.exit(1);
      }

      if (opts.display && !VALID_DISPLAY_MODES.includes(opts.display as DisplayMode)) {
        logger.error(`Invalid display mode: ${opts.display}`);
        process.exit(1);
      }

      // Fetch manifest
      const manifestResult = await fetchManifest(startUrl);
      const manifestValues = manifestResult ? parseManifestValues(manifestResult.manifest) : null;

      if (manifestValues) {
        if (manifestValues.name) logger.info(`Manifest name: ${manifestValues.name}`);
        if (manifestValues.backgroundColor) logger.info(`Manifest background_color: ${manifestValues.backgroundColor}`);
        if (manifestValues.themeColor) logger.info(`Manifest theme_color: ${manifestValues.themeColor}`);
        if (manifestValues.orientation) logger.info(`Manifest orientation: ${manifestValues.orientation}`);
        if (manifestValues.display) logger.info(`Manifest display: ${manifestValues.display}`);
      }

      appName = opts.name || manifestValues?.name || '';
      if (!appName) {
        logger.error('App name is required (--name, or manifest name)');
        process.exit(1);
      }

      const domain = extractDomain(startUrl);
      bundleId = opts.bundleId || reverseDomain(domain);
      logger.info(`Bundle ID: ${bundleId}`);

      allowedOrigins = [domain];
      if (opts.allowed) {
        allowedOrigins.push(...opts.allowed.split(',').map((s) => s.trim()).filter(Boolean));
      }

      authOrigins = opts.auth
        ? opts.auth.split(',').map((s) => s.trim()).filter(Boolean)
        : [];

      features = opts.features
        ? (opts.features.split(',').map((s) => s.trim()).filter((f) => ALL_FEATURES.includes(f as Feature)) as Feature[])
        : [];

      bgColor = opts.bgColor || manifestValues?.backgroundColor || '#FFFFFF';
      themeColor = opts.themeColor || manifestValues?.themeColor || '#007AFF';
      orientation = (opts.orientation as Orientation) || manifestValues?.orientation || 'any';
      displayMode = (opts.display as DisplayMode) || manifestValues?.display || 'standalone';

      // Download icon
      if (manifestResult) {
        const iconSrc = pickBestIcon(manifestResult.manifest);
        if (iconSrc) {
          await downloadIcon(iconSrc, manifestResult.baseUrl, paths.iconSource);
        }
      }
    }

    // Log config summary
    logger.info('Configuring PWAKit...');
    logger.info(`  App name:      ${appName}`);
    logger.info(`  Start URL:     ${startUrl}`);
    logger.info(`  Bundle ID:     ${bundleId}`);
    logger.info(`  Background:    ${bgColor}`);
    logger.info(`  Theme color:   ${themeColor}`);
    logger.info(`  Orientation:   ${orientation}`);
    logger.info(`  Display mode:  ${displayMode}`);
    logger.info(`  Features:      ${features.length > 0 ? features.join(', ') : 'none'}`);

    // Generate config
    const config = generateConfig({
      name: appName,
      bundleId,
      startUrl,
      allowedOrigins,
      authOrigins,
      features,
      backgroundColor: bgColor,
      themeColor,
      orientation,
      displayMode,
    });

    writeConfig(config, paths.configFile);
    logger.success(`Configuration saved to: ${paths.configFile}`);

    // Run sync
    logger.info('Syncing to Xcode project...');
    await runSync(paths, 'apply');

    if (isInteractive) {
      console.log();
      console.log(logger.bold('Next Steps'));
      console.log('----------');
      console.log();
      console.log('  1. Review and customize your configuration:');
      console.log(`     ${logger.cyan(`cat ${paths.configFile}`)}`);
      console.log();
      console.log('  2. Add authentication domains if needed:');
      console.log("     Edit the 'origins.auth' array in pwa-config.json");
      console.log(`     Then run: ${logger.cyan('pwa-kit sync')}`);
      console.log();
      const xcodeprojRelative = path.relative(process.cwd(), paths.pbxproj.replace('/project.pbxproj', ''));
      console.log('  3. Open in Xcode and run:');
      console.log(`     ${logger.cyan(`open ${xcodeprojRelative}`)}`);
      console.log('     Select your simulator or device, then press Cmd+R');
      console.log();
      console.log('  4. For device deployment:');
      console.log('     - Set your Development Team in Xcode');
      console.log('     - Signing & Capabilities tab');
      console.log();
      logger.success('Setup complete!');
      console.log();
    }
  });

interface InitOptions {
  url?: string;
  name?: string;
  bundleId?: string;
  allowed?: string;
  auth?: string;
  bgColor?: string;
  themeColor?: string;
  orientation?: string;
  display?: string;
  features?: string;
  force?: boolean;
  templateVersion?: string;
}
