#!/bin/bash
#
# run-example.sh
# Start the kitchen sink example server and run PWAKit on iOS Simulator
#
# Usage:
#   ./scripts/run-example.sh                          # Start server + run app
#   ./scripts/run-example.sh --device "iPhone 16"     # Run on specific device
#   ./scripts/run-example.sh --server-only            # Only start the server
#
# The script will:
#   1. Start the example HTTPS server (localhost:8443)
#   2. Build and run PWAKit on iOS Simulator
#   3. Clean up the server on exit
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$PROJECT_ROOT/example"
SERVER_PORT=8443
SERVER_PID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Options
SERVER_ONLY=false
DEVICE=""
EXTRA_ARGS=()

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

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Start the kitchen sink example server and run PWAKit on iOS Simulator.

Options:
    -d, --device NAME       Simulator device name (passed to run-simulator.sh)
    -s, --server-only       Only start the example server, don't run the app
    -h, --help              Show this help message

Examples:
    $(basename "$0")                          # Start server + run app
    $(basename "$0") -d "iPhone 16"           # Run on specific device
    $(basename "$0") --server-only            # Only start the server

The example server runs at https://localhost:$SERVER_PORT with a self-signed certificate.
Press Ctrl+C to stop.
EOF
    exit 0
}

cleanup() {
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        print_step "Stopping example server (PID $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        print_success "Server stopped"
    fi
}

trap cleanup EXIT INT TERM

check_prerequisites() {
    # Check for Node.js
    if ! command -v node &>/dev/null; then
        print_error "Node.js is required but not installed"
        print_info "Install via: brew install node"
        exit 1
    fi

    # Check example directory exists
    if [[ ! -d "$EXAMPLE_DIR" ]]; then
        print_error "Example directory not found: $EXAMPLE_DIR"
        exit 1
    fi

    # Check server.js exists
    if [[ ! -f "$EXAMPLE_DIR/server.js" ]]; then
        print_error "Server script not found: $EXAMPLE_DIR/server.js"
        exit 1
    fi
}

build_sdk() {
    local sdk_dir="$PROJECT_ROOT/sdk"
    local sdk_bundle="$sdk_dir/dist/index.global.js"
    local target="$EXAMPLE_DIR/pwakit.js"

    # Skip if pwakit.js already exists and is newer than SDK source
    if [[ -f "$target" && -f "$sdk_bundle" && "$target" -nt "$sdk_bundle" ]]; then
        print_info "pwakit.js is up to date"
        return 0
    fi

    print_step "Building SDK..."

    if [[ ! -d "$sdk_dir/node_modules" ]]; then
        (cd "$sdk_dir" && npm ci --silent)
    fi

    (cd "$sdk_dir" && npm run build --silent)

    if [[ ! -f "$sdk_bundle" ]]; then
        print_error "SDK build failed — $sdk_bundle not found"
        exit 1
    fi

    cp "$sdk_bundle" "$target"
    print_success "pwakit.js built from SDK"
}

wait_for_server() {
    local max_attempts=30
    local attempt=1

    print_step "Waiting for server to be ready..."

    while [[ $attempt -le $max_attempts ]]; do
        # Check if server process is still running
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            print_error "Server process died unexpectedly"
            exit 1
        fi

        # Try to connect to the server
        if curl -sk --max-time 1 "https://localhost:$SERVER_PORT" >/dev/null 2>&1; then
            print_success "Server is ready at https://localhost:$SERVER_PORT"
            return 0
        fi

        sleep 0.5
        attempt=$((attempt + 1))
    done

    print_error "Server failed to start within 15 seconds"
    exit 1
}

start_server() {
    print_step "Starting example server..."

    # Check if port is already in use
    if lsof -i ":$SERVER_PORT" >/dev/null 2>&1; then
        print_warning "Port $SERVER_PORT is already in use"
        local existing_pid
        existing_pid=$(lsof -ti ":$SERVER_PORT" 2>/dev/null | head -1)
        if [[ -n "$existing_pid" ]]; then
            print_info "Existing process: PID $existing_pid"
            read -r -p "Kill existing process? [y/N] " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                kill "$existing_pid" 2>/dev/null || true
                sleep 1
            else
                print_info "Using existing server"
                return 0
            fi
        fi
    fi

    # Start server in background
    cd "$EXAMPLE_DIR"
    node server.js &
    SERVER_PID=$!
    cd "$PROJECT_ROOT"

    print_info "Server PID: $SERVER_PID"

    wait_for_server
}

run_app() {
    print_step "Building and running PWAKit..."

    local args=()
    if [[ -n "$DEVICE" ]]; then
        args+=("--device" "$DEVICE")
    fi
    args+=("${EXTRA_ARGS[@]}")

    "$SCRIPT_DIR/run-simulator.sh" "${args[@]}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -s|--server-only)
            SERVER_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Main
echo ""
echo -e "${BLUE}PWAKit Kitchen Sink${NC}"
echo "==================="
echo ""

check_prerequisites
build_sdk
start_server

if [[ "$SERVER_ONLY" == true ]]; then
    print_success "Server running at https://localhost:$SERVER_PORT"
    print_info "Press Ctrl+C to stop"
    echo ""
    # Wait indefinitely
    wait "$SERVER_PID"
else
    echo ""
    run_app
fi
