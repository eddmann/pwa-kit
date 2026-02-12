#!/bin/bash
#
# sync-config.sh
# Syncs pwa-config.json values to Info.plist
#
# This script reads the origins from pwa-config.json and updates
# WKAppBoundDomains in Info.plist to match. It also syncs appearance
# colors to the Xcode asset catalog colorsets and orientation lock
# to UISupportedInterfaceOrientations:
#   - appearance.backgroundColor → LaunchBackground.colorset
#   - appearance.themeColor → AccentColor.colorset
#   - appearance.orientationLock → UISupportedInterfaceOrientations
#
# Usage:
#   ./scripts/sync-config.sh              # Sync config to Info.plist
#   ./scripts/sync-config.sh --validate   # Validate without modifying
#   ./scripts/sync-config.sh --dry-run    # Show what would change
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$PROJECT_ROOT/src/PWAKit/Resources/pwa-config.json"
INFO_PLIST="$PROJECT_ROOT/src/PWAKit/Info.plist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
VALIDATE_ONLY=false
DRY_RUN=false

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Sync pwa-config.json values to Info.plist.

Options:
    -v, --validate      Validate configuration without modifying files
    -n, --dry-run       Show what would change without modifying files
    -h, --help          Show this help message

The script syncs:
    - origins.allowed + origins.auth → WKAppBoundDomains
    - appearance.backgroundColor → LaunchBackground.colorset
    - appearance.themeColor → AccentColor.colorset
    - appearance.orientationLock → UISupportedInterfaceOrientations
    - Validates privacy descriptions for enabled features
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--validate)
            VALIDATE_ONLY=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Check files exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    print_error "Info.plist not found: $INFO_PLIST"
    exit 1
fi

# Export for Python
export PROJECT_ROOT CONFIG_FILE INFO_PLIST
if [[ "$VALIDATE_ONLY" == "true" ]]; then
    export VALIDATE_ONLY="true"
else
    export VALIDATE_ONLY="false"
fi
if [[ "$DRY_RUN" == "true" ]]; then
    export DRY_RUN="true"
else
    export DRY_RUN="false"
fi

# Use Python for JSON/plist manipulation (available on macOS)
python3 << 'PYTHON_SCRIPT'
import json
import plistlib
import sys
import os

# Get paths from environment
project_root = os.environ.get('PROJECT_ROOT', '.')
config_file = os.environ.get('CONFIG_FILE', '')
info_plist = os.environ.get('INFO_PLIST', '')
validate_only = os.environ.get('VALIDATE_ONLY', 'false') == 'true'
dry_run = os.environ.get('DRY_RUN', 'false') == 'true'

# ANSI colors
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'

def print_success(msg):
    print(f"{GREEN}✓{NC} {msg}")

def print_error(msg):
    print(f"{RED}✗{NC} {msg}", file=sys.stderr)

def print_warning(msg):
    print(f"{YELLOW}!{NC} {msg}")

def print_step(msg):
    print(f"{BLUE}==>{NC} {msg}")

errors = []
warnings = []

# Read pwa-config.json
print_step("Reading pwa-config.json...")
with open(config_file, 'r') as f:
    config = json.load(f)

# Read Info.plist
print_step("Reading Info.plist...")
with open(info_plist, 'rb') as f:
    plist = plistlib.load(f)

# Extract origins
allowed_origins = config.get('origins', {}).get('allowed', [])
auth_origins = config.get('origins', {}).get('auth', [])
all_origins = list(set(allowed_origins + auth_origins))

print(f"   Allowed origins: {allowed_origins}")
print(f"   Auth origins: {auth_origins}")
print(f"   Combined: {all_origins}")

# Get current WKAppBoundDomains
current_domains = plist.get('WKAppBoundDomains', [])
print(f"   Current WKAppBoundDomains: {current_domains}")

# Check if update needed
domains_match = set(current_domains) == set(all_origins)

if domains_match:
    print_success("WKAppBoundDomains is already in sync")
else:
    if dry_run:
        print_warning(f"Would update WKAppBoundDomains: {current_domains} → {all_origins}")
    elif validate_only:
        print_error(f"WKAppBoundDomains mismatch!")
        print(f"   Expected: {all_origins}")
        print(f"   Actual: {current_domains}")
        errors.append("WKAppBoundDomains not in sync with pwa-config.json")
    else:
        plist['WKAppBoundDomains'] = all_origins
        print_success(f"Updated WKAppBoundDomains: {all_origins}")

# Validate privacy descriptions for enabled features
print_step("Validating privacy descriptions...")

features = config.get('features', {})

required_descriptions = {
    'cameraPermission': 'NSCameraUsageDescription',
    'locationPermission': 'NSLocationWhenInUseUsageDescription',
    'biometrics': 'NSFaceIDUsageDescription',
    'healthkit': ['NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription'],
}

# Microphone is optional but recommended
optional_descriptions = {
    'microphone': 'NSMicrophoneUsageDescription',
}

for feature, plist_key in required_descriptions.items():
    if features.get(feature, False):
        keys = plist_key if isinstance(plist_key, list) else [plist_key]
        for key in keys:
            if key not in plist:
                errors.append(f"Missing {key} (required for {feature})")
                print_error(f"Missing {key} (required when features.{feature} is true)")
            else:
                print_success(f"{key} present")

# Check for notifications background mode
if features.get('notifications', False):
    bg_modes = plist.get('UIBackgroundModes', [])
    if 'remote-notification' not in bg_modes:
        errors.append("Missing 'remote-notification' in UIBackgroundModes")
        print_error("Missing 'remote-notification' in UIBackgroundModes (required for notifications)")
    else:
        print_success("UIBackgroundModes includes remote-notification")

plist_modified = not domains_match and not dry_run and not validate_only

# --- Color sync ---
def hex_to_rgb(hex_color):
    """Convert hex color string to RGB float components (0.0-1.0)."""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return r, g, b

def make_colorset_json(r, g, b):
    """Build a colorset Contents.json dict with the given RGB components."""
    return {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue": f"{b:.3f}",
                        "green": f"{g:.3f}",
                        "red": f"{r:.3f}",
                    }
                },
                "idiom": "universal"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

def read_colorset(path):
    """Read existing colorset and return (r, g, b) or None if no color set."""
    try:
        with open(path, 'r') as f:
            data = json.load(f)
        color = data.get('colors', [{}])[0].get('color')
        if not color:
            return None
        components = color.get('components', {})
        return (
            float(components.get('red', 0)),
            float(components.get('green', 0)),
            float(components.get('blue', 0)),
        )
    except (FileNotFoundError, json.JSONDecodeError, ValueError, IndexError):
        return None

def sync_color(hex_value, colorset_path, label):
    """Sync a hex color to a colorset file. Returns True if changes were made."""
    r, g, b = hex_to_rgb(hex_value)
    current = read_colorset(colorset_path)
    target = (round(r, 3), round(g, 3), round(b, 3))

    if current is not None:
        current_rounded = (round(current[0], 3), round(current[1], 3), round(current[2], 3))
    else:
        current_rounded = None

    if current_rounded == target:
        print_success(f"{label} is already in sync ({hex_value})")
        return False

    if dry_run:
        print_warning(f"Would update {label}: {current_rounded} → {target} ({hex_value})")
        return False
    elif validate_only:
        print_error(f"{label} mismatch!")
        print(f"   Expected: {target} ({hex_value})")
        print(f"   Actual: {current_rounded}")
        errors.append(f"{label} not in sync with pwa-config.json")
        return False
    else:
        colorset_data = make_colorset_json(r, g, b)
        with open(colorset_path, 'w') as f:
            json.dump(colorset_data, f, indent=2)
            f.write('\n')
        print_success(f"Updated {label}: {hex_value}")
        return True

assets_dir = os.path.join(project_root, 'src', 'PWAKit', 'Resources', 'Assets.xcassets')
appearance = config.get('appearance', {})

bg_color = appearance.get('backgroundColor')
theme_color = appearance.get('themeColor')

if bg_color or theme_color:
    print_step("Syncing appearance colors...")

if bg_color:
    launch_bg_path = os.path.join(assets_dir, 'LaunchBackground.colorset', 'Contents.json')
    sync_color(bg_color, launch_bg_path, 'LaunchBackground.colorset')

if theme_color:
    accent_path = os.path.join(assets_dir, 'AccentColor.colorset', 'Contents.json')
    sync_color(theme_color, accent_path, 'AccentColor.colorset')

# --- Orientation sync ---
print_step("Syncing orientation lock...")

orientation_lock = appearance.get('orientationLock', 'any')

orientation_map = {
    'portrait': ['UIInterfaceOrientationPortrait'],
    'landscape': ['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'any': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
}

if orientation_lock not in orientation_map:
    print_error(f"Unknown orientationLock value: {orientation_lock}")
    errors.append(f"Invalid orientationLock: {orientation_lock}")
else:
    target_orientations = orientation_map[orientation_lock]
    current_orientations = plist.get('UISupportedInterfaceOrientations', [])
    current_ipad = plist.get('UISupportedInterfaceOrientations~ipad', [])

    orientations_match = (
        set(current_orientations) == set(target_orientations)
        and set(current_ipad) == set(target_orientations)
    )

    if orientations_match:
        print_success(f"UISupportedInterfaceOrientations is already in sync ({orientation_lock})")
    elif dry_run:
        print_warning(f"Would update UISupportedInterfaceOrientations: {current_orientations} → {target_orientations}")
        print_warning(f"Would update UISupportedInterfaceOrientations~ipad: {current_ipad} → {target_orientations}")
    elif validate_only:
        print_error("UISupportedInterfaceOrientations mismatch!")
        print(f"   Expected: {target_orientations}")
        print(f"   Actual: {current_orientations}")
        errors.append("UISupportedInterfaceOrientations not in sync with pwa-config.json")
    else:
        plist['UISupportedInterfaceOrientations'] = target_orientations
        plist['UISupportedInterfaceOrientations~ipad'] = target_orientations
        plist_modified = True
        print_success(f"Updated UISupportedInterfaceOrientations: {target_orientations} ({orientation_lock})")

# Write updated plist if any changes were made
if plist_modified:
    print_step("Writing updated Info.plist...")
    with open(info_plist, 'wb') as f:
        plistlib.dump(plist, f)
    print_success("Info.plist updated successfully")

# Summary
print()
if errors:
    print_error(f"Validation failed with {len(errors)} error(s)")
    for error in errors:
        print(f"   - {error}")
    sys.exit(1)
elif warnings:
    print_warning(f"Completed with {len(warnings)} warning(s)")
    sys.exit(0)
else:
    print_success("Configuration is valid and in sync")
    sys.exit(0)

PYTHON_SCRIPT

exit $?
