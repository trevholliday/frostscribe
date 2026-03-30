# Frostscribe build helpers
#
# Build:
#   make build
#
# One-time tap repo setup (run after creating homebrew-frostscribe on GitHub):
#   make setup-tap

.PHONY: build test build-ui install setup-tap

build:
	swift build -c release

BREW_BIN := $(shell brew --prefix)/bin

install:
	@echo "→ Building CLI and worker..."
	swift build -c release --product frostscribe --product frostscribe-worker
	@echo "→ Installing CLI binaries to $(BREW_BIN)..."
	cp $(CURDIR)/.build/release/frostscribe $(BREW_BIN)/frostscribe
	cp $(CURDIR)/.build/release/frostscribe-worker $(BREW_BIN)/frostscribe-worker
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
	$(CURDIR)/.build/release/frostscribe worker reinstall
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

setup-tap:
	@chmod +x scripts/setup-tap.sh
	./scripts/setup-tap.sh
