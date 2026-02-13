.PHONY: *
.DEFAULT_GOAL := help

SHELL := /bin/bash

CLI_BIN = node cli/dist/index.js
DESTINATION ?= platform=iOS Simulator,name=iPhone 15

help:
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_\-\/]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Global

deps: kit/deps cli/deps sdk/deps ## Install all dependencies

can-release: kit/can-release cli/can-release sdk/can-release ## Run all CI gates

clean: kit/clean cli/clean sdk/clean ## Clean all build artifacts

version: ## Set version across all packages (usage: make version V=0.2.0)
	@if [ -z "$(V)" ]; then echo "Usage: make version V=x.y.z"; exit 1; fi
	@sed -i '' 's/public static let version = ".*"/public static let version = "$(V)"/' kit/src/PWAKitCore/PWAKitCore.swift
	@cd sdk && npm version "$(V)" --no-git-tag-version --allow-same-version
	@cd cli && npm version "$(V)" --no-git-tag-version --allow-same-version
	@echo "Version set to $(V)"

pack: kit/pack cli/pack sdk/pack ## Pack all release artifacts

##@ Kit (iOS)

kit/deps: ## Install Kit dependencies (SwiftFormat, SwiftLint)
	@brew install swiftformat swiftlint 2>/dev/null || brew upgrade swiftformat swiftlint 2>/dev/null || true

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
		-destination '$(DESTINATION)' \
		-quiet

kit/test: ## Run Swift tests
	@xcodebuild test \
		-project kit/PWAKitApp.xcodeproj \
		-scheme PWAKitApp \
		-destination '$(DESTINATION)' \
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

kit/pack: ## Pack Kit as release template tarball
	$(eval VERSION := $(shell sed -n 's/.*public static let version = "\(.*\)"/\1/p' kit/src/PWAKitCore/PWAKitCore.swift))
	@tar -czf pwakit-template-$(VERSION).tar.gz \
		kit/PWAKitApp.xcodeproj/ \
		kit/src/PWAKit/ \
		kit/src/PWAKitCore/ \
		--exclude='kit/src/PWAKit/Resources/pwa-config.json' \
		--exclude='kit/src/PWAKit/Resources/AppIcon-source.png'
	@echo "Created pwakit-template-$(VERSION).tar.gz"

##@ CLI

cli/deps: ## Install CLI dependencies
	@cd cli && npm ci

cli/can-release: cli/build cli/typecheck cli/test ## All CLI checks

cli/build: ## Build CLI
	@cd cli && npm run build

cli/test: ## Run CLI tests
	@cd cli && npm test

cli/typecheck: ## Type check CLI
	@cd cli && npm run typecheck

cli/clean: ## Remove CLI dist
	@rm -rf cli/dist

cli/link: cli/build ## Link CLI globally for local dev
	@cd cli && npm link

cli/pack: cli/build ## Pack CLI as installable tarball
	@cd cli && npm pack

##@ SDK

sdk/deps: ## Install SDK dependencies
	@cd sdk && npm ci

sdk/can-release: sdk/build sdk/typecheck sdk/test ## All SDK checks

sdk/build: ## Build SDK
	@cd sdk && npm run build

sdk/test: ## Run SDK tests
	@cd sdk && npm test

sdk/typecheck: ## Type check SDK
	@cd sdk && npm run typecheck

sdk/clean: ## Remove SDK dist
	@rm -rf sdk/dist

sdk/pack: sdk/build ## Pack SDK as installable tarball
	@cd sdk && npm pack

##@ Example

example/deps: ## Install example dependencies
	@cd example && npm install

example/serve: ## Run kitchen sink demo server
	@./example/run-example.sh --server-only

example/build: sdk/build ## Build example for deployment
	@cd example && rm -rf dist && mkdir -p dist
	@cp example/index.html example/app.js example/styles.css example/manifest.json example/icon-1024.png example/dist/
	@cp sdk/dist/index.global.js example/dist/pwakit.js

example/deploy: example/build ## Deploy to Cloudflare Workers
	@cd example && npx wrangler deploy
