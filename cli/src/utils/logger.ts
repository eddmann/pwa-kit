const isTTY = process.stdout.isTTY ?? false;

const colors = {
  red: isTTY ? '\x1b[0;31m' : '',
  green: isTTY ? '\x1b[0;32m' : '',
  yellow: isTTY ? '\x1b[1;33m' : '',
  blue: isTTY ? '\x1b[0;34m' : '',
  cyan: isTTY ? '\x1b[0;36m' : '',
  bold: isTTY ? '\x1b[1m' : '',
  reset: isTTY ? '\x1b[0m' : '',
};

export const logger = {
  info(msg: string) {
    console.log(`${colors.cyan}info:${colors.reset} ${msg}`);
  },

  success(msg: string) {
    console.log(`${colors.green}✓${colors.reset} ${msg}`);
  },

  warn(msg: string) {
    console.error(`${colors.yellow}!${colors.reset} ${msg}`);
  },

  error(msg: string) {
    console.error(`${colors.red}✗${colors.reset} ${msg}`);
  },

  step(msg: string) {
    console.log(`${colors.blue}==>${colors.reset} ${msg}`);
  },

  detail(msg: string) {
    console.log(`   ${msg}`);
  },

  bold(msg: string): string {
    return `${colors.bold}${msg}${colors.reset}`;
  },

  cyan(msg: string): string {
    return `${colors.cyan}${msg}${colors.reset}`;
  },
};
