#!/bin/bash
#
# setup.sh
# Interactive setup wizard for PWAKit
#
# This script prompts the user for configuration values and generates
# a pwa-config.json file with validated settings.
#
# Usage:
#   ./scripts/setup.sh
#
# The wizard will prompt for:
#   - App name
#   - Start URL (validates HTTPS)
#   - Bundle ID
#   - Allowed origins (auto-extracts from URL)
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/src/PWAKit/Resources/pwa-config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Display welcome banner
show_banner() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                                                               ║${NC}"
    echo -e "${BOLD}║              ${CYAN}PWAKit - Interactive Setup Wizard${NC}${BOLD}              ║${NC}"
    echo -e "${BOLD}║                                                               ║${NC}"
    echo -e "${BOLD}║   This wizard will help you configure your PWA wrapper app.   ║${NC}"
    echo -e "${BOLD}║                                                               ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
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

# Prompt for input with default value
prompt_input() {
    local prompt="$1"
    local default="$2"
    local result

    if [[ -n "$default" ]]; then
        echo -en "${BOLD}$prompt${NC} [${CYAN}$default${NC}]: " >&2
    else
        echo -en "${BOLD}$prompt${NC}: " >&2
    fi

    read -r result

    if [[ -z "$result" && -n "$default" ]]; then
        result="$default"
    fi

    echo "$result"
}

# Prompt for yes/no confirmation
prompt_confirm() {
    local prompt="$1"
    local default="$2"
    local result

    local hint="y/n"
    if [[ "$default" == "y" ]]; then
        hint="Y/n"
    elif [[ "$default" == "n" ]]; then
        hint="y/N"
    fi

    echo -en "${BOLD}$prompt${NC} [$hint]: " >&2
    read -r result

    if [[ -z "$result" ]]; then
        result="$default"
    fi

    case "$result" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Generate a suggested bundle ID from domain
suggest_bundle_id() {
    local domain="$1"
    # Reverse the domain parts (e.g., app.example.com -> com.example.app)
    echo "$domain" | awk -F. '{for(i=NF;i>=1;i--) printf "%s%s", $i, (i>1?".":"")}'
}

# Update Xcode project with bundle ID and app name
update_xcode_project() {
    local bundle_id="$1"
    local app_name="$2"
    local pbxproj="$PROJECT_ROOT/PWAKitApp.xcodeproj/project.pbxproj"

    if [[ ! -f "$pbxproj" ]]; then
        print_warning "Xcode project not found, skipping project update"
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

    print_success "Xcode project updated with bundle ID: $bundle_id"
}

# Update Info.plist with WKAppBoundDomains
update_info_plist() {
    local origins="$1"
    local info_plist="$PROJECT_ROOT/src/PWAKit/Info.plist"

    if [[ ! -f "$info_plist" ]]; then
        print_warning "Info.plist not found, skipping update"
        return
    fi

    # Use Python to update plist (available on macOS)
    python3 << PYTHON_SCRIPT
import plistlib
import sys

info_plist = "$info_plist"
origins_str = '''$origins'''

# Parse origins from the JSON-like string format
domains = []
for part in origins_str.replace('"', '').split(','):
    domain = part.strip()
    if domain:
        domains.append(domain)

# Read existing plist
with open(info_plist, 'rb') as f:
    plist = plistlib.load(f)

# Update WKAppBoundDomains
plist['WKAppBoundDomains'] = domains

# Write updated plist
with open(info_plist, 'wb') as f:
    plistlib.dump(plist, f)

print(f"Updated WKAppBoundDomains with {len(domains)} domain(s)")
PYTHON_SCRIPT

    if [[ $? -eq 0 ]]; then
        print_success "Info.plist updated with WKAppBoundDomains"
    else
        print_error "Failed to update Info.plist"
    fi
}

# Download and install app icon from web manifest
download_app_icon() {
    local start_url="$1"
    local assets_dir="$PROJECT_ROOT/src/PWAKit/Resources/Assets.xcassets"
    local appicon_dir="$assets_dir/AppIcon.appiconset"
    local launchicon_dir="$assets_dir/LaunchIcon.imageset"

    print_step "Fetching app icon from web manifest..."

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
        print_warning "Could not find web manifest, skipping icon download"
        print_info "You can manually add your app icon to: $appicon_dir"
        return
    fi

    print_success "Found manifest at: $manifest_url"

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
        print_warning "No suitable icon found in manifest"
        return
    fi

    # Make icon URL absolute
    if [[ "$icon_url" == /* ]]; then
        icon_url="${base_url}${icon_url}"
    elif [[ "$icon_url" != http* ]]; then
        icon_url="${base_url}/${icon_url}"
    fi

    print_step "Downloading icon: $icon_url"

    # Download icon to temp file
    local temp_icon="/tmp/pwakit_icon_$$.png"
    if ! curl -sL --max-time 30 "$icon_url" -o "$temp_icon" 2>/dev/null; then
        print_warning "Failed to download icon"
        rm -f "$temp_icon"
        return
    fi

    # Verify it's a valid image
    if ! file "$temp_icon" | grep -qiE "image|PNG|JPEG"; then
        print_warning "Downloaded file is not a valid image"
        rm -f "$temp_icon"
        return
    fi

    # Copy to AppIcon (needs to be 1024x1024 for App Store)
    print_step "Installing app icon..."

    # Resize to 1024x1024 for AppIcon using sips (macOS built-in)
    sips -z 1024 1024 "$temp_icon" --out "$appicon_dir/AppIcon.png" >/dev/null 2>&1

    if [[ -f "$appicon_dir/AppIcon.png" ]]; then
        print_success "App icon installed"
    else
        print_warning "Failed to install app icon"
    fi

    # Create LaunchIcon versions (centered, smaller)
    print_step "Creating launch screen icons..."

    # LaunchIcon should be smaller (centered on launch screen)
    sips -z 100 100 "$temp_icon" --out "$launchicon_dir/LaunchIcon.png" >/dev/null 2>&1
    sips -z 200 200 "$temp_icon" --out "$launchicon_dir/LaunchIcon@2x.png" >/dev/null 2>&1
    sips -z 300 300 "$temp_icon" --out "$launchicon_dir/LaunchIcon@3x.png" >/dev/null 2>&1

    if [[ -f "$launchicon_dir/LaunchIcon@2x.png" ]]; then
        print_success "Launch icons installed"
    fi

    # Cleanup
    rm -f "$temp_icon"
}

# Main setup function
main() {
    show_banner

    # Verify we're in the right directory
    if [[ ! -d "$PROJECT_ROOT/PWAKitApp.xcodeproj" ]]; then
        print_error "PWAKitApp.xcodeproj not found. Run this script from the project root."
        exit 1
    fi

    # Check if config already exists
    if [[ -f "$CONFIG_FILE" ]]; then
        print_warning "Configuration file already exists at:"
        echo "  $CONFIG_FILE"
        echo ""
        if ! prompt_confirm "Do you want to overwrite it?" "n"; then
            print_info "Setup cancelled. Existing configuration preserved."
            exit 0
        fi
        echo ""
    fi

    print_step "Let's configure your PWA wrapper app"
    echo ""

    # 1. App Name
    echo -e "${BOLD}Step 1 of 4: App Name${NC}"
    print_info "This is the display name of your app (shown on home screen)."
    APP_NAME=""
    while [[ -z "$APP_NAME" ]]; do
        APP_NAME=$(prompt_input "Enter app name" "")
        if [[ -z "$APP_NAME" ]]; then
            print_error "App name cannot be empty"
        fi
    done
    print_success "App name: $APP_NAME"
    echo ""

    # 2. Start URL
    echo -e "${BOLD}Step 2 of 4: Start URL${NC}"
    print_info "The HTTPS URL of your PWA (must use HTTPS for security)."
    START_URL=""
    while [[ -z "$START_URL" ]]; do
        START_URL=$(prompt_input "Enter start URL" "")
        if [[ -z "$START_URL" ]]; then
            print_error "Start URL cannot be empty"
            START_URL=""
            continue
        fi
        if ! validate_url "$START_URL"; then
            print_error "Invalid URL. Must be a valid HTTPS URL (e.g., https://app.example.com)"
            START_URL=""
        fi
    done
    print_success "Start URL: $START_URL"

    # Extract domain for allowed origins
    DOMAIN=$(extract_domain "$START_URL")
    print_info "Detected domain: $DOMAIN"
    echo ""

    # 3. Bundle ID
    echo -e "${BOLD}Step 3 of 4: Bundle ID${NC}"
    print_info "Unique identifier for your app in reverse domain format."
    SUGGESTED_BUNDLE_ID=$(suggest_bundle_id "$DOMAIN")
    BUNDLE_ID=""
    while [[ -z "$BUNDLE_ID" ]]; do
        BUNDLE_ID=$(prompt_input "Enter bundle ID" "$SUGGESTED_BUNDLE_ID")
        if [[ -z "$BUNDLE_ID" ]]; then
            print_error "Bundle ID cannot be empty"
            BUNDLE_ID=""
            continue
        fi
        if ! validate_bundle_id "$BUNDLE_ID"; then
            print_error "Invalid bundle ID format. Use reverse domain format (e.g., com.example.myapp)"
            BUNDLE_ID=""
        fi
    done
    print_success "Bundle ID: $BUNDLE_ID"
    echo ""

    # 4. Allowed Origins
    echo -e "${BOLD}Step 4 of 4: Allowed Origins${NC}"
    print_info "Domains your app can navigate to (comma-separated for multiple)."
    print_info "The domain from your start URL ($DOMAIN) will always be included."

    EXTRA_ORIGINS=$(prompt_input "Additional allowed domains (optional)" "")

    # Build allowed origins array
    ALLOWED_ORIGINS="\"$DOMAIN\""
    if [[ -n "$EXTRA_ORIGINS" ]]; then
        # Split by comma and add each origin
        IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_ORIGINS"
        for origin in "${EXTRA_ARRAY[@]}"; do
            # Trim whitespace
            origin=$(echo "$origin" | xargs)
            if [[ -n "$origin" ]]; then
                ALLOWED_ORIGINS="$ALLOWED_ORIGINS, \"$origin\""
            fi
        done
    fi
    print_success "Allowed origins configured"
    echo ""

    # Summary
    echo ""
    echo -e "${BOLD}Configuration Summary${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  App Name:        ${CYAN}$APP_NAME${NC}"
    echo -e "  Start URL:       ${CYAN}$START_URL${NC}"
    echo -e "  Bundle ID:       ${CYAN}$BUNDLE_ID${NC}"
    echo -e "  Allowed Origins: ${CYAN}[$ALLOWED_ORIGINS]${NC}"
    echo ""

    if ! prompt_confirm "Generate configuration with these settings?" "y"; then
        print_info "Setup cancelled."
        exit 0
    fi

    echo ""
    print_step "Generating configuration..."

    # Ensure directory exists
    mkdir -p "$(dirname "$CONFIG_FILE")"

    # Generate pwa-config.json
    cat > "$CONFIG_FILE" << EOF
{
  "version": 1,
  "app": {
    "name": "$APP_NAME",
    "bundleId": "$BUNDLE_ID",
    "startUrl": "$START_URL"
  },
  "origins": {
    "allowed": [$ALLOWED_ORIGINS],
    "auth": [],
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

    # Validate the generated JSON
    if command -v python3 &> /dev/null; then
        if python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
            print_success "Configuration file validated"
        else
            print_error "Generated configuration is invalid JSON"
            exit 1
        fi
    elif command -v jq &> /dev/null; then
        if jq empty "$CONFIG_FILE" 2>/dev/null; then
            print_success "Configuration file validated"
        else
            print_error "Generated configuration is invalid JSON"
            exit 1
        fi
    else
        print_warning "Cannot validate JSON (install python3 or jq for validation)"
    fi

    print_success "Configuration saved to: $CONFIG_FILE"
    echo ""

    # Update Xcode project settings
    print_step "Updating Xcode project..."
    update_xcode_project "$BUNDLE_ID" "$APP_NAME"

    # Update Info.plist with WKAppBoundDomains
    print_step "Updating Info.plist..."
    update_info_plist "$ALLOWED_ORIGINS"

    # Download app icon from web manifest
    download_app_icon "$START_URL"

    # Next steps
    echo ""
    echo -e "${BOLD}Next Steps${NC}"
    echo "━━━━━━━━━━"
    echo ""
    echo "  1. Review and customize your configuration:"
    echo -e "     ${CYAN}cat $CONFIG_FILE${NC}"
    echo ""
    echo "  2. Add authentication domains if needed:"
    echo "     Edit the 'origins.auth' array in pwa-config.json"
    echo "     (e.g., accounts.google.com, auth0.com)"
    echo "     Then run: ${CYAN}./scripts/sync-config.sh${NC}"
    echo ""
    echo "  3. Open in Xcode and run:"
    echo -e "     ${CYAN}open PWAKitApp.xcodeproj${NC}"
    echo "     Select your simulator or device, then press Cmd+R"
    echo ""
    echo "  4. For device deployment:"
    echo "     - Set your Development Team in Xcode"
    echo "     - Signing & Capabilities tab"
    echo ""
    print_success "Setup complete!"
    echo ""
}

# Run main function
main "$@"
