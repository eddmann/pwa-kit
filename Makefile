.PHONY: *
.DEFAULT_GOAL := help

SHELL := /bin/bash

CLI_BIN = node cli/dist/index.js

help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_\-\/]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Kit (iOS)

kit/can-release: kit/fmt/check kit/lint kit/build kit/test ## All kit checks

kit/setup: cli/build ## Interactive setup wizard
	@$(CLI_BIN) init

kit/sync: cli/build ## Sync pwa-config.json to Xcode project
	@$(CLI_BIN) sync

kit/open: ## Open Xcode project
	@open kit/PWAKitApp.xcodeproj

kit/build: ## Build iOS app
	@xcodebuild build \
		-project kit/PWAKitApp.xcodeproj \
		-scheme PWAKitApp \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-quiet

kit/test: ## Run Swift tests
	@xcodebuild test \
		-project kit/PWAKitApp.xcodeproj \
		-scheme PWAKitApp \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-quiet

kit/lint: ## Run SwiftLint
	@./kit/scripts/lint.sh

kit/lint/fix: ## Auto-fix lint issues
	@./kit/scripts/lint.sh --fix

kit/fmt: ## Format Swift code
	@./kit/scripts/format.sh

kit/fmt/check: ## Check Swift formatting
	@./kit/scripts/format.sh --check

kit/clean: ## Clean Xcode derived data
	@rm -rf ~/Library/Developer/Xcode/DerivedData/PWAKitApp-*

##@ CLI

cli/can-release: cli/build cli/typecheck cli/test ## All CLI checks

cli/build: ## Build CLI
	@cd cli && npm run build

cli/test: ## Run CLI tests
	@cd cli && npm test

cli/typecheck: ## Type check CLI
	@cd cli && npm run typecheck

cli/clean: ## Remove CLI dist
	@rm -rf cli/dist

##@ SDK

sdk/can-release: sdk/build sdk/typecheck sdk/test ## All SDK checks

sdk/build: ## Build SDK
	@cd sdk && npm run build

sdk/test: ## Run SDK tests
	@cd sdk && npm test

sdk/typecheck: ## Type check SDK
	@cd sdk && npm run typecheck

sdk/clean: ## Remove SDK dist
	@rm -rf sdk/dist

##@ Example

example/serve: ## Run kitchen sink demo server
	@./example/run-example.sh --server-only

example/deploy: ## Deploy to Cloudflare Workers
	@cp example/manifest.json example/icon-1024.png example/dist/
	@cd example && npx wrangler deploy
