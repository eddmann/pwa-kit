#!/bin/bash
#
# format.sh
# Format Swift source code using SwiftFormat
#
# Usage:
#   ./scripts/format.sh                    # Format all Swift files
#   ./scripts/format.sh --check            # Check formatting without making changes
#   ./scripts/format.sh --fix              # Format files (same as no args)
#   ./scripts/format.sh --verbose          # Show detailed output
#   ./scripts/format.sh src/PWAKit     # Format specific path
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.swiftformat"
CHECK_ONLY=false
VERBOSE=false
TARGET_PATH=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PATH]

Format Swift source code using SwiftFormat.

Options:
    -c, --check             Check formatting without making changes (exit 1 if changes needed)
    -f, --fix               Format files and make changes (default behavior)
    -v, --verbose           Show detailed output
    -h, --help              Show this help message

Arguments:
    PATH                    Specific path to format (default: Sources and Tests)

Examples:
    $(basename "$0")                        # Format all source files
    $(basename "$0") --check                # Check if files need formatting
    $(basename "$0") --fix                  # Format files (explicit)
    $(basename "$0") src/PWAKitCore    # Format specific directory
    $(basename "$0") -v --check            # Verbose check mode
EOF
}

check_swiftformat() {
    if ! command -v swiftformat &> /dev/null; then
        print_error "SwiftFormat is not installed"
        echo ""
        echo "Install via Homebrew:"
        echo "  brew install swiftformat"
        echo ""
        echo "Or download from:"
        echo "  https://github.com/nicklockwood/SwiftFormat"
        exit 1
    fi

    local version
    version=$(swiftformat --version 2>&1)
    print_step "Using SwiftFormat: $version"
}

run_swiftformat() {
    local path="$1"
    local exit_code=0

    cd "$PROJECT_ROOT"

    # Build command arguments as an array
    local -a cmd_args=()

    # Add lint mode first if check only
    if [[ "$CHECK_ONLY" == "true" ]]; then
        cmd_args+=("--lint")
    fi

    # Add config file
    if [[ -f "$CONFIG_FILE" ]]; then
        cmd_args+=("--config" "$CONFIG_FILE")
    fi

    # Add verbose flag
    if [[ "$VERBOSE" == "true" ]]; then
        cmd_args+=("--verbose")
    fi

    # Add target path(s)
    if [[ -n "$path" ]]; then
        cmd_args+=("$path")
    else
        # Default to src and tests
        cmd_args+=("src" "tests")
    fi

    print_step "Running: swiftformat ${cmd_args[*]}"
    echo ""

    swiftformat "${cmd_args[@]}" || exit_code=$?

    return $exit_code
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -f|--fix)
            CHECK_ONLY=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

# Main execution
echo ""
echo "PWAKit - Code Formatter"
echo "======================="
echo ""

# Verify we're in the right directory
if [[ ! -d "$PROJECT_ROOT/PWAKitApp.xcodeproj" ]]; then
    print_error "PWAKitApp.xcodeproj not found. Run this script from the project root."
    exit 1
fi

# Check for SwiftFormat
check_swiftformat

# Check for config file
if [[ -f "$CONFIG_FILE" ]]; then
    print_step "Using config: .swiftformat"
else
    print_warning "No .swiftformat config found, using defaults"
fi

echo ""

# Show mode
if [[ "$CHECK_ONLY" == "true" ]]; then
    print_step "Mode: Check only (no changes will be made)"
else
    print_step "Mode: Format (files will be modified)"
fi

echo ""

# Run SwiftFormat
format_exit_code=0
run_swiftformat "$TARGET_PATH" || format_exit_code=$?

echo ""

if [[ $format_exit_code -eq 0 ]]; then
    if [[ "$CHECK_ONLY" == "true" ]]; then
        print_success "All files are properly formatted!"
    else
        print_success "Formatting complete!"
    fi
else
    if [[ "$CHECK_ONLY" == "true" ]]; then
        print_error "Some files need formatting"
        echo ""
        echo "Run without --check to fix:"
        echo "  ./scripts/format.sh"
    else
        print_error "Formatting failed with exit code: $format_exit_code"
    fi
fi

exit $format_exit_code
