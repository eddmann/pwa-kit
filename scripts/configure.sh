#!/bin/bash
#
# configure.sh
# Non-interactive CLI configuration script for PWAKit
#
# This script configures PWAKit using command-line flags or environment
# variables, making it suitable for CI/CD pipelines and scripted setups.
#
# Usage:
#   ./scripts/configure.sh --url "https://my-pwa.example.com"
#
# Environment Variable Fallbacks:
#   PWAKIT_APP_NAME      - App display name
#   PWAKIT_START_URL     - Start URL (HTTPS required)
#   PWAKIT_BUNDLE_ID     - Bundle identifier
#   PWAKIT_ALLOWED       - Comma-separated allowed origins
#   PWAKIT_AUTH_ORIGINS  - Comma-separated auth origins
#
# Auto-detected from web manifest (if available):
#   - App name (from manifest name/short_name)
#   - Background color (from manifest background_color)
#   - Theme color (from manifest theme_color)
#   - Orientation lock (from manifest orientation)
#   - Display mode (from manifest display)
#   - App icon (from manifest icons)
#
# All flags:
#   --url, -u         Start URL (required, must be HTTPS)
#   --name, -n        App name (auto-detected from manifest, or required)
#   --bundle-id, -b   Bundle ID (default: reversed URL domain)
#   --allowed, -a     Additional allowed origins (comma-separated)
#   --auth            Auth origins (comma-separated)
#   --bg-color        Background color hex (default: from manifest or #FFFFFF)
#   --theme-color     Theme/accent color hex (default: from manifest or #007AFF)
#   --orientation     Orientation lock: any, portrait, landscape (default: from manifest or any)
#   --display         Display mode: standalone, fullscreen (default: from manifest or standalone)
#   --features        Comma-separated enabled features (default: none)
#   --output, -o      Output file path (default: src/PWAKit/Resources/pwa-config.json)
#   --force, -f       Overwrite existing config without prompting
#   --quiet, -q       Suppress non-error output
#   --help, -h        Show this help message
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_OUTPUT="$PROJECT_ROOT/src/PWAKit/Resources/pwa-config.json"

# Colors (disabled in quiet mode or non-TTY)
setup_colors() {
    if [[ -t 1 ]] && [[ "$QUIET" != "true" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        CYAN='\033[0;36m'
        BOLD='\033[1m'
        NC='\033[0m'
    else
        RED=''
        GREEN=''
        YELLOW=''
        CYAN=''
        BOLD=''
        NC=''
    fi
}

# Logging functions
log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${CYAN}info:${NC} $1"
    fi
}

log_success() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}success:${NC} $1"
    fi
}

log_warn() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}warning:${NC} $1" >&2
    fi
}

log_error() {
    echo -e "${RED}error:${NC} $1" >&2
}

# Show usage information
show_usage() {
    cat << 'EOF'
Usage: configure.sh [OPTIONS]

Configure PWAKit with the specified settings.

Required options (or environment variables):
  --url, -u <url>         Start URL, HTTPS required (or PWAKIT_START_URL)

Auto-detected (override with flags):
  --name, -n <name>       App display name (or PWAKIT_APP_NAME)
                          Auto-detected from manifest name/short_name
  --bundle-id, -b <id>    Bundle identifier (or PWAKIT_BUNDLE_ID)
                          Auto-generated from reversed URL domain
  --bg-color <hex>        Background color for launch screen
                          (default: from manifest or #FFFFFF, or PWAKIT_BG_COLOR)
  --theme-color <hex>     Theme/accent color
                          (default: from manifest or #007AFF, or PWAKIT_THEME_COLOR)
  --orientation <lock>    Orientation lock: any, portrait, landscape
                          (default: from manifest or any, or PWAKIT_ORIENTATION)
  --display <mode>        Display mode: standalone, fullscreen
                          (default: from manifest or standalone, or PWAKIT_DISPLAY_MODE)

Other optional flags:
  --features <list>       Comma-separated list of enabled features
                          (or PWAKIT_FEATURES)
                          Available: notifications,haptics,biometrics,
                          secureStorage,healthkit,iap,share,print,clipboard
                          Default: none (opt-in to what you need)
  --allowed, -a <origins> Additional allowed origins, comma-separated
                          (or PWAKIT_ALLOWED)
  --auth <origins>        Auth origins for OAuth, comma-separated
                          (or PWAKIT_AUTH_ORIGINS)
  --output, -o <path>     Output file path
                          (default: src/PWAKit/Resources/pwa-config.json)
  --force, -f             Overwrite existing config without prompting
  --quiet, -q             Suppress non-error output
  --help, -h              Show this help message

Examples:
  # Minimal - just a URL, everything else auto-detected
  ./scripts/configure.sh --url "https://my-pwa.example.com"

  # With features enabled
  ./scripts/configure.sh \
    --url "https://my-pwa.example.com" \
    --features "notifications,haptics,share"

  # Override auto-detected values
  ./scripts/configure.sh \
    --url "https://my-pwa.example.com" \
    --name "My App" \
    --bg-color "#1a1a2e" \
    --orientation portrait

  # Force overwrite existing config
  ./scripts/configure.sh --force --url "https://my-pwa.example.com"
EOF
}

# Validate HTTPS URL
validate_url() {
    local url="$1"

    # Check if URL starts with https://
    if [[ ! "$url" =~ ^https:// ]]; then
        return 1
    fi

    # Check if URL has a valid domain
    if [[ ! "$url" =~ ^https://[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}(/.*)?$ ]]; then
        return 1
    fi

    return 0
}

# Extract domain from URL
extract_domain() {
    local url="$1"
    # Remove protocol and path, keep domain
    echo "$url" | sed -E 's|^https://([^/]+).*|\1|'
}

# Validate hex color format
validate_hex_color() {
    local color="$1"
    if [[ ! "$color" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        return 1
    fi
    return 0
}

# Validate bundle ID format
validate_bundle_id() {
    local bundle_id="$1"

    # Bundle ID should be reverse domain format (e.g., com.example.app)
    if [[ ! "$bundle_id" =~ ^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*)+$ ]]; then
        return 1
    fi

    return 0
}

# Generate bundle ID by reversing the domain segments
# e.g. step-wars.eddmann.workers.dev → dev.workers.eddmann.step-wars
reverse_domain() {
    local domain="$1"
    echo "$domain" | tr '.' '\n' | tail -r | paste -sd '.' -
}

# Convert comma-separated string to JSON array
to_json_array() {
    local input="$1"
    local result=""

    if [[ -z "$input" ]]; then
        echo "[]"
        return
    fi

    IFS=',' read -ra items <<< "$input"
    for i in "${!items[@]}"; do
        # Trim whitespace
        item=$(echo "${items[$i]}" | xargs)
        if [[ -n "$item" ]]; then
            if [[ -n "$result" ]]; then
                result="$result, "
            fi
            result="$result\"$item\""
        fi
    done

    echo "[$result]"
}

# Update Xcode project with bundle ID and app name
update_xcode_project() {
    local bundle_id="$1"
    local app_name="$2"
    local pbxproj="$PROJECT_ROOT/PWAKitApp.xcodeproj/project.pbxproj"

    if [[ ! -f "$pbxproj" ]]; then
        log_warn "Xcode project not found, skipping project update"
        return
    fi

    # Update PRODUCT_BUNDLE_IDENTIFIER
    sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $bundle_id;/g" "$pbxproj"

    # Update INFOPLIST_KEY_CFBundleDisplayName if present
    if grep -q "INFOPLIST_KEY_CFBundleDisplayName" "$pbxproj"; then
        sed -i '' "s/INFOPLIST_KEY_CFBundleDisplayName = \"[^\"]*\"/INFOPLIST_KEY_CFBundleDisplayName = \"$app_name\"/g" "$pbxproj"
    fi

    # Update PRODUCT_NAME if it's set to PWAKitApp
    sed -i '' "s/PRODUCT_NAME = \"PWAKitApp\"/PRODUCT_NAME = \"$app_name\"/g" "$pbxproj"

    log_success "Xcode project updated with bundle ID: $bundle_id"
}

# Update Info.plist with WKAppBoundDomains
update_info_plist() {
    local allowed_origins="$1"
    local auth_origins="$2"
    local info_plist="$PROJECT_ROOT/src/PWAKit/Info.plist"

    if [[ ! -f "$info_plist" ]]; then
        log_warn "Info.plist not found, skipping update"
        return
    fi

    # Use Python to update plist (available on macOS)
    python3 << PYTHON_SCRIPT
import plistlib

info_plist = "$info_plist"
allowed = "$allowed_origins"
auth = "$auth_origins"

# Parse domains from comma-separated lists
domains = set()
for origins in [allowed, auth]:
    for domain in origins.split(','):
        domain = domain.strip()
        if domain:
            domains.add(domain)

# Read existing plist
with open(info_plist, 'rb') as f:
    plist = plistlib.load(f)

# Update WKAppBoundDomains
plist['WKAppBoundDomains'] = sorted(list(domains))

# Write updated plist
with open(info_plist, 'wb') as f:
    plistlib.dump(plist, f)

print(f"Updated WKAppBoundDomains with {len(domains)} domain(s)")
PYTHON_SCRIPT

    if [[ $? -eq 0 ]]; then
        log_success "Info.plist updated with WKAppBoundDomains"
    else
        log_error "Failed to update Info.plist"
    fi
}

# Try to fetch a manifest URL and validate it as JSON
# Returns 0 and sets MANIFEST_CONTENT on success
try_manifest_url() {
    local url="$1"
    local content
    content=$(curl -sL --max-time 10 "$url" 2>/dev/null)
    if echo "$content" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        MANIFEST_CONTENT="$content"
        log_success "Found manifest at: $url"
        return 0
    fi
    return 1
}

# Fetch web manifest by parsing <link rel="manifest"> from the start URL,
# then falling back to well-known paths.
# Sets MANIFEST_CONTENT and MANIFEST_BASE_URL globals
fetch_manifest() {
    local start_url="$1"

    log_info "Fetching web manifest..."

    # Extract base URL
    MANIFEST_BASE_URL=$(echo "$start_url" | sed -E 's|(https?://[^/]+).*|\1|')
    MANIFEST_CONTENT=""

    # First: parse <link rel="manifest"> from the start URL HTML
    local html
    html=$(curl -sL --max-time 10 "$start_url" 2>/dev/null)
    if [[ -n "$html" ]]; then
        local manifest_href
        manifest_href=$(echo "$html" | python3 -c "
import sys, re, html

content = sys.stdin.read()
# Match <link rel=\"manifest\" href=\"...\"> in any attribute order
match = re.search(r'<link\b[^>]*\brel=[\"'\'']manifest[\"'\''][^>]*\bhref=[\"'\'']([^\"'\'']+)[\"'\'']', content, re.IGNORECASE)
if not match:
    # Try reverse order: href before rel
    match = re.search(r'<link\b[^>]*\bhref=[\"'\'']([^\"'\'']+)[\"'\''][^>]*\brel=[\"'\'']manifest[\"'\'']', content, re.IGNORECASE)
if match:
    print(html.unescape(match.group(1)))
" 2>/dev/null)

        if [[ -n "$manifest_href" ]]; then
            # Make manifest URL absolute
            local manifest_url
            if [[ "$manifest_href" == http* ]]; then
                manifest_url="$manifest_href"
            elif [[ "$manifest_href" == /* ]]; then
                manifest_url="${MANIFEST_BASE_URL}${manifest_href}"
            else
                manifest_url="${MANIFEST_BASE_URL}/${manifest_href}"
            fi

            log_info "Found <link rel=\"manifest\"> pointing to: $manifest_url"
            if try_manifest_url "$manifest_url"; then
                return 0
            fi
        fi
    fi

    # Fallback: try well-known paths
    for path in "/manifest.json" "/manifest.webmanifest" "/site.webmanifest"; do
        if try_manifest_url "${MANIFEST_BASE_URL}${path}"; then
            return 0
        fi
    done

    log_warn "Could not find web manifest"
    return 1
}

# Extract values from the fetched manifest into MANIFEST_* variables
# Sets: MANIFEST_NAME, MANIFEST_BG_COLOR, MANIFEST_THEME_COLOR, MANIFEST_ORIENTATION, MANIFEST_DISPLAY
extract_manifest_values() {
    MANIFEST_NAME=""
    MANIFEST_BG_COLOR=""
    MANIFEST_THEME_COLOR=""
    MANIFEST_ORIENTATION=""
    MANIFEST_DISPLAY=""

    if [[ -z "$MANIFEST_CONTENT" ]]; then
        return
    fi

    # Extract all values in a single Python call
    local values
    values=$(python3 -c "
import json, sys

try:
    manifest = json.loads(sys.argv[1])

    # Name: prefer short_name, fall back to name
    name = manifest.get('short_name', '') or manifest.get('name', '')
    print(name)

    # Background color (CSS hex)
    print(manifest.get('background_color', ''))

    # Theme color (CSS hex)
    print(manifest.get('theme_color', ''))

    # Orientation: map W3C values to PWAKit values
    orientation = manifest.get('orientation', '')
    if orientation in ('portrait', 'portrait-primary', 'portrait-secondary', 'natural'):
        print('portrait')
    elif orientation in ('landscape', 'landscape-primary', 'landscape-secondary'):
        print('landscape')
    elif orientation == 'any':
        print('any')
    else:
        print('')

    # Display mode: only accept values PWAKit supports
    display = manifest.get('display', '')
    if display in ('standalone', 'fullscreen'):
        print(display)
    else:
        print('')
except:
    print('')
    print('')
    print('')
    print('')
    print('')
" "$MANIFEST_CONTENT")

    # Read the five lines into variables
    MANIFEST_NAME=$(echo "$values" | sed -n '1p')
    MANIFEST_BG_COLOR=$(echo "$values" | sed -n '2p')
    MANIFEST_THEME_COLOR=$(echo "$values" | sed -n '3p')
    MANIFEST_ORIENTATION=$(echo "$values" | sed -n '4p')
    MANIFEST_DISPLAY=$(echo "$values" | sed -n '5p')

    # Validate manifest colors are valid hex (manifest may use shorthand or named colors)
    if [[ -n "$MANIFEST_BG_COLOR" ]] && ! validate_hex_color "$MANIFEST_BG_COLOR"; then
        log_warn "Manifest background_color '$MANIFEST_BG_COLOR' is not a valid 6-digit hex, ignoring"
        MANIFEST_BG_COLOR=""
    fi
    if [[ -n "$MANIFEST_THEME_COLOR" ]] && ! validate_hex_color "$MANIFEST_THEME_COLOR"; then
        log_warn "Manifest theme_color '$MANIFEST_THEME_COLOR' is not a valid 6-digit hex, ignoring"
        MANIFEST_THEME_COLOR=""
    fi

    # Log what we found
    [[ -n "$MANIFEST_NAME" ]] && log_info "Manifest name: $MANIFEST_NAME"
    [[ -n "$MANIFEST_BG_COLOR" ]] && log_info "Manifest background_color: $MANIFEST_BG_COLOR"
    [[ -n "$MANIFEST_THEME_COLOR" ]] && log_info "Manifest theme_color: $MANIFEST_THEME_COLOR"
    [[ -n "$MANIFEST_ORIENTATION" ]] && log_info "Manifest orientation: $MANIFEST_ORIENTATION"
    [[ -n "$MANIFEST_DISPLAY" ]] && log_info "Manifest display: $MANIFEST_DISPLAY"
}

# Download and install app icon from web manifest
# Requires fetch_manifest to have been called first
download_app_icon() {
    if [[ -z "$MANIFEST_CONTENT" ]]; then
        log_warn "No manifest available, skipping icon download"
        return
    fi

    local assets_dir="$PROJECT_ROOT/src/PWAKit/Resources/Assets.xcassets"
    local appicon_dir="$assets_dir/AppIcon.appiconset"
    local launchicon_dir="$assets_dir/LaunchIcon.imageset"

    # Extract best icon URL using Python
    local icon_url
    icon_url=$(python3 -c "
import json, sys

try:
    manifest = json.loads(sys.argv[1])
    icons = manifest.get('icons', [])

    if not icons:
        sys.exit(1)

    best_icon = None
    best_size = 0

    for icon in icons:
        src = icon.get('src', '')
        sizes = icon.get('sizes', '0x0')
        purpose = icon.get('purpose', 'any')

        if purpose == 'maskable':
            continue

        size_str = sizes.split()[0] if sizes else '0x0'
        try:
            w, h = size_str.lower().split('x')
            size = min(int(w), int(h))
        except:
            size = 0

        if size > best_size or (size == best_size and '.png' in src.lower()):
            best_size = size
            best_icon = src

    if best_icon:
        print(best_icon)
except:
    sys.exit(1)
" "$MANIFEST_CONTENT")

    if [[ -z "$icon_url" ]]; then
        log_warn "No suitable icon found in manifest"
        return
    fi

    # Make icon URL absolute
    if [[ "$icon_url" == /* ]]; then
        icon_url="${MANIFEST_BASE_URL}${icon_url}"
    elif [[ "$icon_url" != http* ]]; then
        icon_url="${MANIFEST_BASE_URL}/${icon_url}"
    fi

    log_info "Downloading icon: $icon_url"

    # Download icon to temp file
    local temp_icon="/tmp/pwakit_icon_$$.png"
    if ! curl -sL --max-time 30 "$icon_url" -o "$temp_icon" 2>/dev/null; then
        log_warn "Failed to download icon"
        rm -f "$temp_icon"
        return
    fi

    # Verify it's a valid image
    if ! file "$temp_icon" | grep -qiE "image|PNG|JPEG"; then
        log_warn "Downloaded file is not a valid image"
        rm -f "$temp_icon"
        return
    fi

    # Copy to AppIcon (needs to be 1024x1024 for App Store)
    log_info "Installing app icon..."

    # Resize to 1024x1024 for AppIcon using sips (macOS built-in)
    sips -z 1024 1024 "$temp_icon" --out "$appicon_dir/AppIcon.png" >/dev/null 2>&1

    if [[ -f "$appicon_dir/AppIcon.png" ]]; then
        log_success "App icon installed"
    else
        log_warn "Failed to install app icon"
    fi

    # Create LaunchIcon versions (centered, smaller)
    log_info "Creating launch screen icons..."

    # LaunchIcon should be smaller (centered on launch screen)
    sips -z 100 100 "$temp_icon" --out "$launchicon_dir/LaunchIcon.png" >/dev/null 2>&1
    sips -z 200 200 "$temp_icon" --out "$launchicon_dir/LaunchIcon@2x.png" >/dev/null 2>&1
    sips -z 300 300 "$temp_icon" --out "$launchicon_dir/LaunchIcon@3x.png" >/dev/null 2>&1

    if [[ -f "$launchicon_dir/LaunchIcon@2x.png" ]]; then
        log_success "Launch icons installed"
    fi

    # Cleanup
    rm -f "$temp_icon"
}

# Parse command line arguments
parse_args() {
    # Set defaults from environment variables
    APP_NAME="${PWAKIT_APP_NAME:-}"
    START_URL="${PWAKIT_START_URL:-}"
    BUNDLE_ID="${PWAKIT_BUNDLE_ID:-}"
    ALLOWED_ORIGINS="${PWAKIT_ALLOWED:-}"
    AUTH_ORIGINS="${PWAKIT_AUTH_ORIGINS:-}"
    BG_COLOR="${PWAKIT_BG_COLOR:-}"
    THEME_COLOR="${PWAKIT_THEME_COLOR:-}"
    ORIENTATION="${PWAKIT_ORIENTATION:-}"
    DISPLAY_MODE="${PWAKIT_DISPLAY_MODE:-}"
    FEATURES="${PWAKIT_FEATURES:-}"
    OUTPUT_FILE="$DEFAULT_OUTPUT"
    FORCE="false"
    QUIET="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name|-n)
                APP_NAME="$2"
                shift 2
                ;;
            --url|-u)
                START_URL="$2"
                shift 2
                ;;
            --bundle-id|-b)
                BUNDLE_ID="$2"
                shift 2
                ;;
            --allowed|-a)
                ALLOWED_ORIGINS="$2"
                shift 2
                ;;
            --auth)
                AUTH_ORIGINS="$2"
                shift 2
                ;;
            --bg-color)
                BG_COLOR="$2"
                shift 2
                ;;
            --theme-color)
                THEME_COLOR="$2"
                shift 2
                ;;
            --orientation)
                ORIENTATION="$2"
                shift 2
                ;;
            --display)
                DISPLAY_MODE="$2"
                shift 2
                ;;
            --features)
                FEATURES="$2"
                shift 2
                ;;
            --output|-o)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --force|-f)
                FORCE="true"
                shift
                ;;
            --quiet|-q)
                QUIET="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# Validate all required inputs
validate_inputs() {
    local has_error="false"

    # Note: APP_NAME and BUNDLE_ID validated after manifest fetch (can be auto-generated)

    if [[ -z "$START_URL" ]]; then
        log_error "Start URL is required (--url or PWAKIT_START_URL)"
        has_error="true"
    elif ! validate_url "$START_URL"; then
        log_error "Invalid start URL: $START_URL"
        log_error "URL must be a valid HTTPS URL (e.g., https://app.example.com)"
        has_error="true"
    fi

    if [[ -n "$BUNDLE_ID" ]] && ! validate_bundle_id "$BUNDLE_ID"; then
        log_error "Invalid bundle ID format: $BUNDLE_ID"
        log_error "Bundle ID must be in reverse domain format (e.g., com.example.app)"
        has_error="true"
    fi

    if [[ -n "$BG_COLOR" ]] && ! validate_hex_color "$BG_COLOR"; then
        log_error "Invalid background color: $BG_COLOR"
        log_error "Must be a 6-digit hex color (e.g., #FFFFFF)"
        has_error="true"
    fi

    if [[ -n "$THEME_COLOR" ]] && ! validate_hex_color "$THEME_COLOR"; then
        log_error "Invalid theme color: $THEME_COLOR"
        log_error "Must be a 6-digit hex color (e.g., #007AFF)"
        has_error="true"
    fi

    if [[ -n "$ORIENTATION" && "$ORIENTATION" != "any" && "$ORIENTATION" != "portrait" && "$ORIENTATION" != "landscape" ]]; then
        log_error "Invalid orientation: $ORIENTATION"
        log_error "Must be one of: any, portrait, landscape"
        has_error="true"
    fi

    if [[ -n "$DISPLAY_MODE" && "$DISPLAY_MODE" != "standalone" && "$DISPLAY_MODE" != "fullscreen" ]]; then
        log_error "Invalid display mode: $DISPLAY_MODE"
        log_error "Must be one of: standalone, fullscreen"
        has_error="true"
    fi

    if [[ "$has_error" == "true" ]]; then
        echo "" >&2
        echo "Use --help for usage information" >&2
        exit 1
    fi
}

# Check if a feature is enabled
# Uses the FEATURES variable (comma-separated list of enabled features)
feature_enabled() {
    local feature="$1"
    echo ",$FEATURES," | grep -q ",$feature,"
}

# Generate the configuration file
generate_config() {
    # Extract domain from URL for allowed origins
    local domain
    domain=$(extract_domain "$START_URL")

    # Build allowed origins array (always include the main domain)
    local allowed_list="$domain"
    if [[ -n "$ALLOWED_ORIGINS" ]]; then
        allowed_list="$domain,$ALLOWED_ORIGINS"
    fi
    local allowed_json
    allowed_json=$(to_json_array "$allowed_list")

    # Build auth origins array
    local auth_json
    auth_json=$(to_json_array "$AUTH_ORIGINS")

    # Ensure output directory exists
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # Generate the JSON configuration
    cat > "$OUTPUT_FILE" << EOF
{
  "version": 1,
  "app": {
    "name": "$APP_NAME",
    "bundleId": "$BUNDLE_ID",
    "startUrl": "$START_URL"
  },
  "origins": {
    "allowed": $allowed_json,
    "auth": $auth_json,
    "external": []
  },
  "features": {
    "notifications": $(feature_enabled notifications && echo true || echo false),
    "haptics": $(feature_enabled haptics && echo true || echo false),
    "biometrics": $(feature_enabled biometrics && echo true || echo false),
    "secureStorage": $(feature_enabled secureStorage && echo true || echo false),
    "healthkit": $(feature_enabled healthkit && echo true || echo false),
    "iap": $(feature_enabled iap && echo true || echo false),
    "share": $(feature_enabled share && echo true || echo false),
    "print": $(feature_enabled print && echo true || echo false),
    "clipboard": $(feature_enabled clipboard && echo true || echo false)
  },
  "appearance": {
    "displayMode": "$DISPLAY_MODE",
    "pullToRefresh": true,
    "adaptiveStyle": true,
    "statusBarStyle": "default",
    "orientationLock": "$ORIENTATION",
    "backgroundColor": "$BG_COLOR",
    "themeColor": "$THEME_COLOR"
  },
  "notifications": {
    "provider": "apns"
  }
}
EOF
}

# Validate generated JSON
validate_json() {
    if command -v python3 &> /dev/null; then
        if python3 -c "import json; json.load(open('$OUTPUT_FILE'))" 2>/dev/null; then
            return 0
        fi
    elif command -v jq &> /dev/null; then
        if jq empty "$OUTPUT_FILE" 2>/dev/null; then
            return 0
        fi
    else
        # No validator available, assume success
        log_warn "Cannot validate JSON (python3 or jq not available)"
        return 0
    fi

    return 1
}

# Main function
main() {
    parse_args "$@"
    setup_colors

    # Validate inputs before proceeding
    validate_inputs

    # Check for existing config
    if [[ -f "$OUTPUT_FILE" ]] && [[ "$FORCE" != "true" ]]; then
        log_error "Configuration file already exists: $OUTPUT_FILE"
        log_error "Use --force to overwrite"
        exit 1
    fi

    # Fetch web manifest and extract values (icon, name, colors, orientation)
    fetch_manifest "$START_URL" || true
    extract_manifest_values

    # Fill in blanks from manifest, then hardcoded defaults
    # Priority: CLI/env > manifest > auto-generated/default
    [[ -z "$APP_NAME" ]] && APP_NAME="$MANIFEST_NAME"
    [[ -z "$BG_COLOR" ]] && BG_COLOR="${MANIFEST_BG_COLOR:-#FFFFFF}"
    [[ -z "$THEME_COLOR" ]] && THEME_COLOR="${MANIFEST_THEME_COLOR:-#007AFF}"
    [[ -z "$ORIENTATION" ]] && ORIENTATION="${MANIFEST_ORIENTATION:-any}"
    [[ -z "$DISPLAY_MODE" ]] && DISPLAY_MODE="${MANIFEST_DISPLAY:-standalone}"
    # Features default to none — opt-in to what you need
    [[ -z "$FEATURES" ]] && FEATURES=""

    # Auto-generate bundle ID from reversed domain if not provided
    if [[ -z "$BUNDLE_ID" ]]; then
        local domain
        domain=$(extract_domain "$START_URL")
        BUNDLE_ID=$(reverse_domain "$domain")
        log_info "Bundle ID from URL: $BUNDLE_ID"
    fi

    # Validate app name (may have come from manifest)
    if [[ -z "$APP_NAME" ]]; then
        log_error "App name is required (--name, PWAKIT_APP_NAME, or manifest name)"
        echo "" >&2
        echo "Use --help for usage information" >&2
        exit 1
    fi

    # Log what we're doing
    log_info "Configuring PWAKit..."
    log_info "  App name:      $APP_NAME"
    log_info "  Start URL:     $START_URL"
    log_info "  Bundle ID:     $BUNDLE_ID"
    log_info "  Background:    $BG_COLOR"
    log_info "  Theme color:   $THEME_COLOR"
    log_info "  Orientation:   $ORIENTATION"
    log_info "  Display mode:  $DISPLAY_MODE"
    log_info "  Features:      $FEATURES"

    # Generate configuration
    generate_config

    # Validate generated JSON
    if ! validate_json; then
        log_error "Generated configuration is invalid JSON"
        rm -f "$OUTPUT_FILE"
        exit 1
    fi

    log_success "Configuration saved to: $OUTPUT_FILE"

    # Update Xcode project settings
    log_info "Updating Xcode project..."
    update_xcode_project "$BUNDLE_ID" "$APP_NAME"

    # Update Info.plist with WKAppBoundDomains
    local domain
    domain=$(extract_domain "$START_URL")
    local all_origins="$domain"
    if [[ -n "$ALLOWED_ORIGINS" ]]; then
        all_origins="$all_origins,$ALLOWED_ORIGINS"
    fi
    log_info "Updating Info.plist..."
    update_info_plist "$all_origins" "$AUTH_ORIGINS"

    # Download app icon from web manifest
    download_app_icon

    # Sync appearance colors to asset catalog
    log_info "Syncing appearance colors..."
    "$SCRIPT_DIR/sync-config.sh"
}

# Run main function
main "$@"
