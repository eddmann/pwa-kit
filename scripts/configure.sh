#!/bin/bash
#
# configure.sh
# Configuration script for PWAKit (interactive wizard or CLI flags)
#
# This script produces the two sources of truth:
#   1. pwa-config.json — all app configuration
#   2. AppIcon-source.png — source icon (downloaded from manifest)
#
# Then calls sync-config.sh to derive everything else (pbxproj, Info.plist,
# colorsets, icon variants).
#
# Usage:
#   ./scripts/configure.sh --interactive       # Interactive wizard
#   ./scripts/configure.sh --url "https://..."  # Non-interactive CLI
#   ./scripts/configure.sh -i                   # Short form
#
# When no --url is provided and stdin is a TTY, interactive mode is used
# automatically.
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
#   --interactive, -i Auto-detect when no --url + TTY (default in that case)
#   --url, -u         Start URL (required in non-interactive mode, must be HTTPS)
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
ICON_SOURCE="$PROJECT_ROOT/src/PWAKit/Resources/AppIcon-source.png"

# Colors (disabled in quiet mode or non-TTY)
setup_colors() {
    if [[ -t 1 ]] && [[ "$QUIET" != "true" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        CYAN='\033[0;36m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m'
    else
        RED=''
        GREEN=''
        YELLOW=''
        CYAN=''
        BLUE=''
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

Modes:
  --interactive, -i         Interactive wizard (auto-detected when no --url)

Required options (non-interactive):
  --url, -u <url>         Start URL (HTTPS required)

Auto-detected (override with flags):
  --name, -n <name>       App display name (auto-detected from manifest)
  --bundle-id, -b <id>    Bundle identifier (auto-generated from reversed URL domain)
  --bg-color <hex>        Background color for launch screen
                          (default: from manifest or #FFFFFF)
  --theme-color <hex>     Theme/accent color
                          (default: from manifest or #007AFF)
  --orientation <lock>    Orientation lock: any, portrait, landscape
                          (default: from manifest or any)
  --display <mode>        Display mode: standalone, fullscreen
                          (default: from manifest or standalone)

Other optional flags:
  --features <list>       Comma-separated list of enabled features
                          Available: notifications,haptics,biometrics,
                          secureStorage,healthkit,iap,share,print,clipboard
                          Default: none (opt-in to what you need)
  --allowed, -a <origins> Additional allowed origins, comma-separated
  --auth <origins>        Auth origins for OAuth, comma-separated
  --output, -o <path>     Output file path
                          (default: src/PWAKit/Resources/pwa-config.json)
  --force, -f             Overwrite existing config without prompting
  --quiet, -q             Suppress non-error output
  --help, -h              Show this help message

Examples:
  # Interactive wizard
  ./scripts/configure.sh --interactive

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

# ─── Validation helpers ──────────────────────────────────────────────────────

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
# e.g. step-wars.eddmann.workers.dev -> dev.workers.eddmann.step-wars
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

# ─── Interactive mode ─────────────────────────────────────────────────────────

# Display welcome banner
show_banner() {
    echo ""
    echo -e "${BOLD}+---------------------------------------------------------------+${NC}"
    echo -e "${BOLD}|                                                               |${NC}"
    echo -e "${BOLD}|              ${CYAN}PWAKit - Interactive Setup Wizard${NC}${BOLD}              |${NC}"
    echo -e "${BOLD}|                                                               |${NC}"
    echo -e "${BOLD}|   This wizard will help you configure your PWA wrapper app.   |${NC}"
    echo -e "${BOLD}|                                                               |${NC}"
    echo -e "${BOLD}+---------------------------------------------------------------+${NC}"
    echo ""
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

# Run the interactive wizard to populate global variables
run_interactive() {
    show_banner

    # Verify we're in the right directory
    if [[ ! -d "$PROJECT_ROOT/PWAKitApp.xcodeproj" ]]; then
        log_error "PWAKitApp.xcodeproj not found. Run this script from the project root."
        exit 1
    fi

    # Check if config already exists
    if [[ -f "$OUTPUT_FILE" ]] && [[ "$FORCE" != "true" ]]; then
        log_warn "Configuration file already exists at:"
        echo "  $OUTPUT_FILE"
        echo ""
        if ! prompt_confirm "Do you want to overwrite it?" "n"; then
            log_info "Setup cancelled. Existing configuration preserved."
            exit 0
        fi
        echo ""
        FORCE="true"
    fi

    echo -e "${BLUE}==>${NC} Let's configure your PWA wrapper app"
    echo ""

    # Step 1: Start URL
    echo -e "${BOLD}Step 1 of 5: Start URL${NC}"
    echo -e "${CYAN}info:${NC} The HTTPS URL of your PWA (must use HTTPS for security)."
    while [[ -z "$START_URL" ]]; do
        START_URL=$(prompt_input "Enter start URL" "")
        if [[ -z "$START_URL" ]]; then
            log_error "Start URL cannot be empty"
            START_URL=""
            continue
        fi
        if ! validate_url "$START_URL"; then
            log_error "Invalid URL. Must be a valid HTTPS URL (e.g., https://app.example.com)"
            START_URL=""
        fi
    done
    log_success "Start URL: $START_URL"

    # Extract domain
    local domain
    domain=$(extract_domain "$START_URL")
    log_info "Detected domain: $domain"
    echo ""

    # Fetch manifest early so we can pre-fill name
    log_info "Checking for web manifest..."
    fetch_manifest "$START_URL" || true
    extract_manifest_values

    # Step 2: App Name (pre-filled from manifest)
    echo -e "${BOLD}Step 2 of 5: App Name${NC}"
    echo -e "${CYAN}info:${NC} This is the display name of your app (shown on home screen)."
    local default_name="$MANIFEST_NAME"
    while [[ -z "$APP_NAME" ]]; do
        APP_NAME=$(prompt_input "Enter app name" "$default_name")
        if [[ -z "$APP_NAME" ]]; then
            log_error "App name cannot be empty"
        fi
    done
    log_success "App name: $APP_NAME"
    echo ""

    # Step 3: Bundle ID (pre-filled from reversed domain)
    echo -e "${BOLD}Step 3 of 5: Bundle ID${NC}"
    echo -e "${CYAN}info:${NC} Unique identifier for your app in reverse domain format."
    local suggested_bundle_id
    suggested_bundle_id=$(reverse_domain "$domain")
    while [[ -z "$BUNDLE_ID" ]]; do
        BUNDLE_ID=$(prompt_input "Enter bundle ID" "$suggested_bundle_id")
        if [[ -z "$BUNDLE_ID" ]]; then
            log_error "Bundle ID cannot be empty"
            BUNDLE_ID=""
            continue
        fi
        if ! validate_bundle_id "$BUNDLE_ID"; then
            log_error "Invalid bundle ID format. Use reverse domain format (e.g., com.example.myapp)"
            BUNDLE_ID=""
        fi
    done
    log_success "Bundle ID: $BUNDLE_ID"
    echo ""

    # Step 4: Allowed Origins
    echo -e "${BOLD}Step 4 of 5: Allowed Origins${NC}"
    echo -e "${CYAN}info:${NC} Domains your app can navigate to (comma-separated for multiple)."
    echo -e "${CYAN}info:${NC} The domain from your start URL ($domain) will always be included."

    ALLOWED_ORIGINS=$(prompt_input "Additional allowed domains (optional)" "")
    log_success "Allowed origins configured"
    echo ""

    # Step 5: Features
    echo -e "${BOLD}Step 5 of 5: Features${NC}"
    echo -e "${CYAN}info:${NC} Enable native capabilities your PWA can access via the JavaScript bridge."
    echo ""
    echo "  1) notifications   - Push notifications (APNS)"
    echo "  2) haptics         - Haptic feedback"
    echo "  3) biometrics      - Face ID / Touch ID"
    echo "  4) secureStorage   - Keychain storage"
    echo "  5) healthkit       - HealthKit data"
    echo "  6) iap             - In-App Purchases"
    echo "  7) share           - Native share sheet"
    echo "  8) print           - Print support"
    echo "  9) clipboard       - Clipboard access"
    echo ""
    echo -e "${CYAN}info:${NC} Enter comma-separated numbers, 'all', or 'none' (default: none)"

    local feature_input
    feature_input=$(prompt_input "Enable features" "none")

    local all_features=("notifications" "haptics" "biometrics" "secureStorage" "healthkit" "iap" "share" "print" "clipboard")

    if [[ "$feature_input" == "all" ]]; then
        FEATURES=$(IFS=','; echo "${all_features[*]}")
    elif [[ "$feature_input" == "none" || -z "$feature_input" ]]; then
        FEATURES=""
    else
        # Parse comma-separated numbers
        local selected_features=""
        IFS=',' read -ra nums <<< "$feature_input"
        for num in "${nums[@]}"; do
            num=$(echo "$num" | xargs)
            if [[ "$num" =~ ^[1-9]$ ]] && [[ "$num" -le ${#all_features[@]} ]]; then
                local idx=$((num - 1))
                if [[ -n "$selected_features" ]]; then
                    selected_features="$selected_features,"
                fi
                selected_features="$selected_features${all_features[$idx]}"
            else
                log_warn "Ignoring invalid feature number: $num"
            fi
        done
        FEATURES="$selected_features"
    fi

    if [[ -n "$FEATURES" ]]; then
        log_success "Features: $FEATURES"
    else
        log_success "Features: none"
    fi
    echo ""

    # Use manifest defaults for appearance if available
    [[ -z "$BG_COLOR" ]] && BG_COLOR="${MANIFEST_BG_COLOR:-#FFFFFF}"
    [[ -z "$THEME_COLOR" ]] && THEME_COLOR="${MANIFEST_THEME_COLOR:-#007AFF}"
    [[ -z "$ORIENTATION" ]] && ORIENTATION="${MANIFEST_ORIENTATION:-any}"
    [[ -z "$DISPLAY_MODE" ]] && DISPLAY_MODE="${MANIFEST_DISPLAY:-standalone}"

    # Summary
    echo ""
    echo -e "${BOLD}Configuration Summary${NC}"
    echo "---------------------"
    echo -e "  App Name:       ${CYAN}$APP_NAME${NC}"
    echo -e "  Start URL:      ${CYAN}$START_URL${NC}"
    echo -e "  Bundle ID:      ${CYAN}$BUNDLE_ID${NC}"
    echo -e "  Background:     ${CYAN}$BG_COLOR${NC}"
    echo -e "  Theme color:    ${CYAN}$THEME_COLOR${NC}"
    echo -e "  Orientation:    ${CYAN}$ORIENTATION${NC}"
    echo -e "  Display mode:   ${CYAN}$DISPLAY_MODE${NC}"
    echo -e "  Features:       ${CYAN}${FEATURES:-none}${NC}"
    echo ""

    if ! prompt_confirm "Generate configuration with these settings?" "y"; then
        log_info "Setup cancelled."
        exit 0
    fi

    echo ""
}

# ─── Manifest fetching ────────────────────────────────────────────────────────

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

# ─── Icon download ────────────────────────────────────────────────────────────

# Download app icon from web manifest to AppIcon-source.png
# Requires fetch_manifest to have been called first
download_app_icon() {
    if [[ -z "$MANIFEST_CONTENT" ]]; then
        log_warn "No manifest available, skipping icon download"
        return
    fi

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

    # Save as the source icon
    cp "$temp_icon" "$ICON_SOURCE"
    rm -f "$temp_icon"

    if [[ -f "$ICON_SOURCE" ]]; then
        log_success "Source icon saved to: $ICON_SOURCE"
    else
        log_warn "Failed to save source icon"
    fi
}

# ─── Argument parsing ─────────────────────────────────────────────────────────

# Parse command line arguments
parse_args() {
    APP_NAME=""
    START_URL=""
    BUNDLE_ID=""
    ALLOWED_ORIGINS=""
    AUTH_ORIGINS=""
    BG_COLOR=""
    THEME_COLOR=""
    ORIENTATION=""
    DISPLAY_MODE=""
    FEATURES=""
    OUTPUT_FILE="$DEFAULT_OUTPUT"
    FORCE="false"
    QUIET="false"
    INTERACTIVE="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive|-i)
                INTERACTIVE="true"
                shift
                ;;
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

    # Auto-detect interactive mode: no --url provided and stdin is a TTY
    if [[ "$INTERACTIVE" != "true" && -z "$START_URL" && -t 0 ]]; then
        INTERACTIVE="true"
    fi
}

# Validate all required inputs (non-interactive mode)
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

# ─── Config generation ────────────────────────────────────────────────────────

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

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"
    setup_colors

    if [[ "$INTERACTIVE" == "true" ]]; then
        # Interactive mode: wizard populates all variables
        run_interactive
    else
        # Non-interactive mode: validate CLI inputs
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
        # Features default to none -- opt-in to what you need
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
    log_info "  Features:      ${FEATURES:-none}"

    # Generate configuration
    generate_config

    # Validate generated JSON
    if ! validate_json; then
        log_error "Generated configuration is invalid JSON"
        rm -f "$OUTPUT_FILE"
        exit 1
    fi

    log_success "Configuration saved to: $OUTPUT_FILE"

    # Download app icon from web manifest -> AppIcon-source.png
    download_app_icon

    # Sync everything to Xcode project (pbxproj, Info.plist, colors, icons)
    log_info "Syncing to Xcode project..."
    "$SCRIPT_DIR/sync-config.sh"

    # Next steps (interactive mode only)
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo ""
        echo -e "${BOLD}Next Steps${NC}"
        echo "----------"
        echo ""
        echo "  1. Review and customize your configuration:"
        echo -e "     ${CYAN}cat $OUTPUT_FILE${NC}"
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
        log_success "Setup complete!"
        echo ""
    fi
}

# Run main function
main "$@"
