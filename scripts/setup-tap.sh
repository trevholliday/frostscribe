#!/usr/bin/env bash
# One-time script to seed the homebrew-frostscribe tap repo.
#
# Run this AFTER creating an empty repo at:
#   https://github.com/trevholliday/homebrew-frostscribe
#
# Usage:
#   ./scripts/setup-tap.sh

set -euo pipefail

REPO_URL="https://github.com/trevholliday/homebrew-frostscribe.git"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="$(mktemp -d)"

echo "→ Cloning tap repo..."
git clone "$REPO_URL" "$WORK_DIR/tap"

echo "→ Copying formula..."
cp "$REPO_ROOT/homebrew/frostscribe.rb" "$WORK_DIR/tap/frostscribe.rb"

cat > "$WORK_DIR/tap/README.md" << 'EOF'
# homebrew-frostscribe

Homebrew tap for [Frostscribe](https://github.com/trevholliday/frostscribe) — a native macOS disc ripping and encoding tool for Jellyfin, Plex, and Kodi.

## Install

```bash
brew tap trevholliday/frostscribe
brew install frostscribe
```

## What gets installed

- `frostscribe` — interactive CLI for ripping discs
- `frostscribe-worker` — launchd encode worker daemon

## After install

```bash
frostscribe init        # run the setup wizard
frostscribe worker start  # install and start the encode worker
frostscribe rip           # rip your first disc
```

MakeMKV is required and must be downloaded separately from https://www.makemkv.com
EOF

cd "$WORK_DIR/tap"
git config user.name "$(git -C "$REPO_ROOT" config user.name)"
git config user.email "$(git -C "$REPO_ROOT" config user.email)"
git add frostscribe.rb README.md
git commit -m "Initial formula (placeholder — first release will fill in sha256s)"
git push origin main

rm -rf "$WORK_DIR"
echo ""
echo "✓ Tap repo seeded. Add TAP_REPO_TOKEN secret to the frostscribe repo,"
echo "  then tag a release: make release VERSION=1.0.0"
