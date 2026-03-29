# Frostscribe release helpers
#
# Build:
#   make build
#
# Tag and push a release (triggers the GitHub Actions release workflow):
#   make release VERSION=1.0.0
#
# One-time tap repo setup (run after creating homebrew-frostscribe on GitHub):
#   make setup-tap

.PHONY: build test build-ui install release setup-tap

build:
	swift build -c release

install:
	@echo "→ Building CLI and worker..."
	swift build -c release --product frostscribe --product frostscribe-worker
	@echo "→ Installing CLI binaries to /usr/local/bin..."
	cp $(CURDIR)/.build/release/frostscribe /usr/local/bin/frostscribe
	cp $(CURDIR)/.build/release/frostscribe-worker /usr/local/bin/frostscribe-worker
	@echo "→ Building FrostscribeUI..."
	xcodebuild -project FrostscribeUI/FrostscribeUI.xcodeproj \
	           -scheme FrostscribeUI \
	           -configuration Release \
	           -derivedDataPath /tmp/frostscribe-build \
	           build 2>&1 | grep -E "error:|warning:|BUILD"
	@echo "→ Installing FrostscribeUI..."
	rm -rf /Applications/FrostscribeUI.app
	cp -R /tmp/frostscribe-build/Build/Products/Release/FrostscribeUI.app /Applications/
	@echo "→ Reinstalling and starting worker..."
	frostscribe worker reinstall
	@echo ""
	@echo "✓ All done."

test:
	swift test

build-ui:
	@echo "→ Archiving FrostscribeUI..."
	xcodebuild -project FrostscribeUI/FrostscribeUI.xcodeproj \
	           -scheme FrostscribeUI \
	           -configuration Release \
	           -archivePath .build/FrostscribeUI.xcarchive \
	           archive
	@echo "→ Exporting .app..."
	xcodebuild -exportArchive \
	           -archivePath .build/FrostscribeUI.xcarchive \
	           -exportPath .build/FrostscribeUI \
	           -exportOptionsPlist scripts/ExportOptions.plist
	@echo "→ Installing to /Applications..."
	cp -r .build/FrostscribeUI/FrostscribeUI.app /Applications/
	@echo ""
	@echo "✓ FrostscribeUI installed to /Applications/FrostscribeUI.app"

release:
ifndef VERSION
	$(error VERSION is required — run: make release VERSION=1.0.0)
endif
	@# Update version in CLI source
	sed -i '' 's/version: "[^"]*"/version: "$(VERSION)"/' \
		Sources/FrostscribeCLI/Frostscribe.swift
	@# Update version in formula template
	sed -i '' 's/^  version "[^"]*"/  version "$(VERSION)"/' \
		homebrew/frostscribe.rb
	@echo "→ Committing version bump..."
	git add Sources/FrostscribeCLI/Frostscribe.swift homebrew/frostscribe.rb
	git diff --cached --quiet || git commit -m "chore: bump version to $(VERSION)"
	@echo "→ Tagging v$(VERSION)..."
	git tag v$(VERSION)
	@echo "→ Pushing..."
	git push origin HEAD
	git push origin v$(VERSION)
	@echo ""
	@echo "✓ Tag pushed. GitHub Actions will build, release, and update the tap."
	@echo "  Watch progress at: https://github.com/trevholliday/frostscribe/actions"

setup-tap:
	@chmod +x scripts/setup-tap.sh
	./scripts/setup-tap.sh
