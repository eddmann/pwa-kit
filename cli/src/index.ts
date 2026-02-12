import { Command } from 'commander';
import { initCommand } from './commands/init.js';
import { syncCommand } from './commands/sync.js';

const program = new Command()
  .name('pwa-kit')
  .description('CLI for creating and configuring PWAKit iOS apps')
  .version('0.1.0');

program.addCommand(initCommand);
program.addCommand(syncCommand);

program.parse();
