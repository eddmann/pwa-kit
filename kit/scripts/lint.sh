#!/bin/bash
#
# lint.sh
# Run SwiftLint on PWAKit source code
#
# Usage:
#   ./scripts/lint.sh                    # Lint all Swift files
#   ./scripts/lint.sh --fix              # Auto-fix linting issues
#   ./scripts/lint.sh --strict           # Fail on warnings (for CI)
#   ./scripts/lint.sh --verbose          # Show detailed output
#   ./scripts/lint.sh src/PWAKit     # Lint specific path
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.swiftlint.yml"
AUTO_FIX=false
STRICT_MODE=false
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

Run SwiftLint on Swift source code.

Options:
    -f, --fix               Auto-fix correctable linting issues
    -s, --strict            Treat warnings as errors (useful for CI)
    -v, --verbose           Show detailed output
    -a, --analyze           Run analyzer rules (slower, requires compilation)
    -h, --help              Show this help message

Arguments:
    PATH                    Specific path to lint (default: all configured paths)

Examples:
    $(basename "$0")                        # Lint all source files
    $(basename "$0") --fix                  # Auto-fix issues
    $(basename "$0") --strict               # Fail on warnings
    $(basename "$0") src/PWAKitCore    # Lint specific directory
    $(basename "$0") -v --fix              # Verbose fix mode
EOF
}

check_swiftlint() {
    if ! command -v swiftlint &> /dev/null; then
        print_error "SwiftLint is not installed"
        echo ""
        echo "Install via Homebrew:"
        echo "  brew install swiftlint"
        echo ""
        echo "Or download from:"
        echo "  https://github.com/realm/SwiftLint"
        exit 1
    fi

    local version
    version=$(swiftlint version 2>&1)
    print_step "Using SwiftLint: $version"
}

run_swiftlint() {
    local path="$1"
    local exit_code=0

    cd "$PROJECT_ROOT"

    # Build command arguments as an array
    local -a cmd_args=()

    # Add fix mode if requested
    if [[ "$AUTO_FIX" == "true" ]]; then
        cmd_args+=("--fix")
    fi

    # Add strict mode if requested
    if [[ "$STRICT_MODE" == "true" ]]; then
        cmd_args+=("--strict")
    fi

    # Add config file
    if [[ -f "$CONFIG_FILE" ]]; then
        cmd_args+=("--config" "$CONFIG_FILE")
    fi

    # Add target path if specified
    if [[ -n "$path" ]]; then
        cmd_args+=("--path" "$path")
    fi

    # Reporter format
    if [[ "$VERBOSE" == "true" ]]; then
        # Use emoji reporter for verbose mode
        cmd_args+=("--reporter" "emoji")
    fi

    print_step "Running: swiftlint ${cmd_args[*]}"
    echo ""

    swiftlint "${cmd_args[@]}" || exit_code=$?

    return $exit_code
}

run_format_first() {
    # If we're in fix mode, run SwiftFormat first
    if [[ "$AUTO_FIX" == "true" ]]; then
        print_step "Running SwiftFormat before SwiftLint..."
        echo ""

        local format_script="$SCRIPT_DIR/format.sh"
        if [[ -x "$format_script" ]]; then
            "$format_script" --fix || {
                print_warning "SwiftFormat completed with warnings"
            }
            echo ""
        else
            print_warning "format.sh not found or not executable, skipping SwiftFormat"
        fi
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--fix)
            AUTO_FIX=true
            shift
            ;;
        -s|--strict)
            STRICT_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -a|--analyze)
            # Note: Analyzer rules are configured in .swiftlint.yml
            # They require the --analyze flag which needs compilation info
            print_warning "Analyzer mode requires additional setup"
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
echo "PWAKit - Code Linter"
echo "===================="
echo ""

# Verify we're in the right directory
if [[ ! -d "$PROJECT_ROOT/PWAKitApp.xcodeproj" ]]; then
    print_error "PWAKitApp.xcodeproj not found. Run this script from the project root."
    exit 1
fi

# Check for SwiftLint
check_swiftlint

# Check for config file
if [[ -f "$CONFIG_FILE" ]]; then
    print_step "Using config: .swiftlint.yml"
else
    print_warning "No .swiftlint.yml config found, using defaults"
fi

echo ""

# Show mode
if [[ "$AUTO_FIX" == "true" ]]; then
    print_step "Mode: Auto-fix (correctable issues will be fixed)"
else
    print_step "Mode: Lint only (no changes will be made)"
fi

if [[ "$STRICT_MODE" == "true" ]]; then
    print_step "Strict: Warnings treated as errors"
fi

echo ""

# Run SwiftFormat first if in fix mode
run_format_first

# Run SwiftLint
lint_exit_code=0
run_swiftlint "$TARGET_PATH" || lint_exit_code=$?

echo ""

if [[ $lint_exit_code -eq 0 ]]; then
    print_success "Linting passed!"
else
    if [[ "$AUTO_FIX" == "true" ]]; then
        print_warning "Some issues could not be auto-fixed"
    fi
    print_error "Linting failed with exit code: $lint_exit_code"
fi

exit $lint_exit_code
