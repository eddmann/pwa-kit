# PWAKit Makefile
#
# A simple interface for common development commands.
#
# Usage:
#   make help     - Show available commands
#   make setup    - Run interactive setup wizard
#   make open     - Open Xcode project
#   make example  - Run the kitchen sink demo
#   make lint     - Run linters
#   make format   - Format code
#   make clean    - Clean build artifacts
#

.PHONY: help setup configure open example lint format clean check prereq sync build test

# Default target
.DEFAULT_GOAL := help

# Colors for terminal output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

#==============================================================================
# Help
#==============================================================================

help: ## Show available commands
	@echo ""
	@echo "$(BLUE)PWAKit - Development Commands$(NC)"
	@echo "=============================="
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make <target>"
	@echo ""
	@echo "$(GREEN)Getting Started:$(NC)"
	@echo "  $(BLUE)prereq$(NC)        Check prerequisites"
	@echo "  $(BLUE)setup$(NC)         Run interactive setup wizard"
	@echo "  $(BLUE)open$(NC)          Open Xcode project"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@echo "  $(BLUE)build$(NC)         Build iOS app"
	@echo "  $(BLUE)test$(NC)          Run tests"
	@echo "  $(BLUE)example$(NC)       Run kitchen sink demo server"
	@echo "  $(BLUE)sync$(NC)          Sync pwa-config.json to Info.plist"
	@echo "  $(BLUE)lint$(NC)          Run SwiftLint"
	@echo "  $(BLUE)format$(NC)        Format code with SwiftFormat"
	@echo "  $(BLUE)clean$(NC)         Clean build artifacts"
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  1. make prereq     # Verify tools are installed"
	@echo "  2. make setup      # Configure your PWA"
	@echo "  3. make open       # Open in Xcode, then Cmd+R to run"
	@echo ""

#==============================================================================
# Setup & Configuration
#==============================================================================

prereq: ## Check prerequisites
	@./scripts/check-prerequisites.sh

setup: ## Run interactive setup wizard
	@./scripts/configure.sh --interactive

configure: ## Run non-interactive configuration (use with environment variables)
	@./scripts/configure.sh

sync: ## Sync pwa-config.json to Info.plist
	@./scripts/sync-config.sh

#==============================================================================
# Development
#==============================================================================

open: ## Open Xcode project
	@echo "$(BLUE)==>$(NC) Opening PWAKitApp.xcodeproj..."
	@open PWAKitApp.xcodeproj

build: ## Build iOS app
	@echo "$(BLUE)==>$(NC) Building PWAKitApp..."
	@xcodebuild build \
		-project PWAKitApp.xcodeproj \
		-scheme PWAKitApp \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-quiet
	@echo "$(GREEN)✓$(NC) Build complete"

test: ## Run tests
	@echo "$(BLUE)==>$(NC) Running tests..."
	@xcodebuild test \
		-project PWAKitApp.xcodeproj \
		-scheme PWAKitApp \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-quiet
	@echo "$(GREEN)✓$(NC) Tests complete"

example: ## Run kitchen sink demo server
	@./scripts/run-example.sh --server-only

deploy-example: ## Deploy kitchen sink demo to Cloudflare Workers
	@echo "$(BLUE)==>$(NC) Deploying example..."
	@cp example/manifest.json example/icon-1024.png example/dist/
	@cd example && npx wrangler deploy
	@echo "$(GREEN)✓$(NC) Deployed to https://pwakit-example.eddmann.workers.dev"

#==============================================================================
# Code Quality
#==============================================================================

lint: ## Run linters (SwiftLint)
	@./scripts/lint.sh

lint-fix: ## Run linters and auto-fix issues
	@./scripts/lint.sh --fix

format: ## Format code (SwiftFormat)
	@./scripts/format.sh

format-check: ## Check code formatting without making changes
	@./scripts/format.sh --check

check: format-check lint ## Check formatting and lint

#==============================================================================
# Maintenance
#==============================================================================

clean: ## Clean build artifacts
	@echo "$(BLUE)==>$(NC) Cleaning build artifacts..."
	@rm -rf .build
	@rm -rf .build-cache
	@rm -rf .coverage
	@rm -rf ~/Library/Developer/Xcode/DerivedData/PWAKitApp-*
	@echo "$(GREEN)✓$(NC) Clean complete"
