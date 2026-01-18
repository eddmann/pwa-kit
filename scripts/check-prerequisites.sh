#!/bin/bash
#
# check-prerequisites.sh
# Verifies all required tools are installed for PWAKit
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

print_check() {
    printf "  %-20s" "$1"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

print_warn() {
    echo -e "${YELLOW}!${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

echo ""
echo "PWAKit - Prerequisites Check"
echo "=================================="
echo ""

# Required Tools
echo "Required Tools:"
echo "---------------"

# macOS
print_check "macOS"
macos_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
if [[ "$macos_version" != "unknown" ]]; then
    major_version=$(echo "$macos_version" | cut -d. -f1)
    if [[ "$major_version" -ge 14 ]]; then
        print_pass "$macos_version"
    else
        print_warn "$macos_version (14+ recommended)"
    fi
else
    print_fail "Could not detect"
fi

# Xcode
print_check "Xcode"
if command -v xcodebuild &> /dev/null; then
    xcode_version=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')
    if [[ -n "$xcode_version" ]]; then
        major_version=$(echo "$xcode_version" | cut -d. -f1)
        if [[ "$major_version" -ge 15 ]]; then
            print_pass "$xcode_version"
        else
            print_warn "$xcode_version (15+ required for iOS 17+)"
        fi
    else
        print_warn "Installed (version unknown)"
    fi
else
    print_fail "Not installed"
    echo "         Install from: App Store"
fi

# Python3 (for setup scripts)
print_check "Python 3"
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version 2>/dev/null | awk '{print $2}')
    print_pass "$python_version"
else
    print_fail "Not installed (required for setup scripts)"
fi

echo ""
echo "Optional Tools:"
echo "---------------"

# Node.js (for example server)
print_check "Node.js"
if command -v node &> /dev/null; then
    node_version=$(node --version 2>/dev/null)
    print_pass "$node_version"
else
    print_warn "Not installed (needed for example server)"
    echo "         Install with: brew install node"
fi

# SwiftFormat (for code formatting)
print_check "SwiftFormat"
if command -v swiftformat &> /dev/null; then
    sf_version=$(swiftformat --version 2>/dev/null)
    print_pass "$sf_version"
else
    print_warn "Not installed (optional, for code formatting)"
    echo "         Install with: brew install swiftformat"
fi

# SwiftLint (for code linting)
print_check "SwiftLint"
if command -v swiftlint &> /dev/null; then
    sl_version=$(swiftlint version 2>/dev/null)
    print_pass "$sl_version"
else
    print_warn "Not installed (optional, for code linting)"
    echo "         Install with: brew install swiftlint"
fi

echo ""
echo "=================================="
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$WARNINGS warnings${NC}"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Some required tools are missing. Please install them before continuing.${NC}"
    echo ""
    exit 1
else
    echo -e "${GREEN}All required tools are installed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  ./scripts/setup.sh        # Configure your PWA"
    echo "  open PWAKitApp.xcodeproj  # Open in Xcode"
    echo ""
    exit 0
fi
