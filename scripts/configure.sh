#!/bin/bash
#
# configure.sh
# Non-interactive CLI configuration script for PWAKit
#
# This script configures PWAKit using command-line flags or environment
# variables, making it suitable for CI/CD pipelines and scripted setups.
#
# Usage:
#   ./scripts/configure.sh \
#     --name "My App" \
#     --url "https://app.example.com" \
#     --bundle-id "com.example.app"
#
# Environment Variable Fallbacks:
#   PWAKIT_APP_NAME      - App display name
#   PWAKIT_START_URL     - Start URL (HTTPS required)
#   PWAKIT_BUNDLE_ID     - Bundle identifier
#   PWAKIT_ALLOWED       - Comma-separated allowed origins
#   PWAKIT_AUTH_ORIGINS  - Comma-separated auth origins
#
# All flags:
#   --name, -n        App name (required)
#   --url, -u         Start URL (required, must be HTTPS)
#   --bundle-id, -b   Bundle ID (required)
#   --allowed, -a     Additional allowed origins (comma-separated)
#   --auth            Auth origins (comma-separated)
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
  --name, -n <name>       App display name (or PWAKIT_APP_NAME)
  --url, -u <url>         Start URL, HTTPS required (or PWAKIT_START_URL)
  --bundle-id, -b <id>    Bundle identifier (or PWAKIT_BUNDLE_ID)

Optional flags:
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
  # Basic configuration
  ./scripts/configure.sh \
    --name "My App" \
    --url "https://app.example.com" \
    --bundle-id "com.example.app"

  # With auth origins for OAuth
  ./scripts/configure.sh \
    --name "My App" \
    --url "https://app.example.com" \
    --bundle-id "com.example.app" \
    --auth "accounts.google.com,auth0.com"

  # Using environment variables (CI/CD)
  export PWAKIT_APP_NAME="My App"
  export PWAKIT_START_URL="https://app.example.com"
  export PWAKIT_BUNDLE_ID="com.example.app"
  ./scripts/configure.sh --quiet

  # Force overwrite existing config
  ./scripts/configure.sh --force \
    --name "My App" \
    --url "https://app.example.com" \
    --bundle-id "com.example.app"
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

# Validate bundle ID format
validate_bundle_id() {
    local bundle_id="$1"

    # Bundle ID should be reverse domain format (e.g., com.example.app)
    if [[ ! "$bundle_id" =~ ^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*)+$ ]]; then
        return 1
    fi

    return 0
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

# Download and install app icon from web manifest
download_app_icon() {
    local start_url="$1"
    local assets_dir="$PROJECT_ROOT/src/PWAKit/Resources/Assets.xcassets"
    local appicon_dir="$assets_dir/AppIcon.appiconset"
    local launchicon_dir="$assets_dir/LaunchIcon.imageset"

    log_info "Fetching app icon from web manifest..."

    # Extract base URL
    local base_url
    base_url=$(echo "$start_url" | sed -E 's|(https?://[^/]+).*|\1|')

    # Try to fetch manifest.json from common locations
    local manifest_url=""
    local manifest_content=""

    for path in "/manifest.json" "/manifest.webmanifest" "/site.webmanifest"; do
        local try_url="${base_url}${path}"
        manifest_content=$(curl -sL --max-time 10 "$try_url" 2>/dev/null)
        if echo "$manifest_content" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
            manifest_url="$try_url"
            break
        fi
    done

    if [[ -z "$manifest_url" ]]; then
        log_warn "Could not find web manifest, skipping icon download"
        return
    fi

    log_success "Found manifest at: $manifest_url"

    # Extract best icon URL using Python
    local icon_url
    icon_url=$(echo "$manifest_content" | python3 << 'PYTHON_SCRIPT'
import json
import sys

try:
    manifest = json.load(sys.stdin)
    icons = manifest.get('icons', [])

    if not icons:
        sys.exit(1)

    # Find the best icon (largest, prefer square, prefer png)
    best_icon = None
    best_size = 0

    for icon in icons:
        src = icon.get('src', '')
        sizes = icon.get('sizes', '0x0')
        purpose = icon.get('purpose', 'any')

        # Skip maskable-only icons
        if purpose == 'maskable':
            continue

        # Parse size (take first if multiple)
        size_str = sizes.split()[0] if sizes else '0x0'
        try:
            w, h = size_str.lower().split('x')
            size = min(int(w), int(h))  # Use smaller dimension
        except:
            size = 0

        # Prefer larger icons, prefer png
        if size > best_size or (size == best_size and '.png' in src.lower()):
            best_size = size
            best_icon = src

    if best_icon:
        print(best_icon)
except:
    sys.exit(1)
PYTHON_SCRIPT
)

    if [[ -z "$icon_url" ]]; then
        log_warn "No suitable icon found in manifest"
        return
    fi

    # Make icon URL absolute
    if [[ "$icon_url" == /* ]]; then
        icon_url="${base_url}${icon_url}"
    elif [[ "$icon_url" != http* ]]; then
        icon_url="${base_url}/${icon_url}"
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

    # Check required fields
    if [[ -z "$APP_NAME" ]]; then
        log_error "App name is required (--name or PWAKIT_APP_NAME)"
        has_error="true"
    fi

    if [[ -z "$START_URL" ]]; then
        log_error "Start URL is required (--url or PWAKIT_START_URL)"
        has_error="true"
    elif ! validate_url "$START_URL"; then
        log_error "Invalid start URL: $START_URL"
        log_error "URL must be a valid HTTPS URL (e.g., https://app.example.com)"
        has_error="true"
    fi

    if [[ -z "$BUNDLE_ID" ]]; then
        log_error "Bundle ID is required (--bundle-id or PWAKIT_BUNDLE_ID)"
        has_error="true"
    elif ! validate_bundle_id "$BUNDLE_ID"; then
        log_error "Invalid bundle ID format: $BUNDLE_ID"
        log_error "Bundle ID must be in reverse domain format (e.g., com.example.app)"
        has_error="true"
    fi

    if [[ "$has_error" == "true" ]]; then
        echo "" >&2
        echo "Use --help for usage information" >&2
        exit 1
    fi
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
    "notifications": true,
    "haptics": true,
    "biometrics": true,
    "secureStorage": true,
    "healthkit": false,
    "iap": false,
    "share": true,
    "print": true,
    "clipboard": true
  },
  "appearance": {
    "displayMode": "standalone",
    "pullToRefresh": true,
    "adaptiveStyle": true,
    "statusBarStyle": "default"
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

    # Log what we're doing
    log_info "Configuring PWAKit..."
    log_info "  App name:   $APP_NAME"
    log_info "  Start URL:  $START_URL"
    log_info "  Bundle ID:  $BUNDLE_ID"

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
    download_app_icon "$START_URL"
}

# Run main function
main "$@"
