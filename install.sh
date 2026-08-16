#!/bin/bash
# Drop afk-marc's two scripts into the current project.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/marcsoehn99/afk-marc/main/install.sh | bash

set -euo pipefail

REPO="https://raw.githubusercontent.com/marcsoehn99/afk-marc/main"
DEST="${AFK_MARC_DIR:-.}"

mkdir -p "$DEST"

curl -fsSL "$REPO/afk-tickets.sh" -o "$DEST/afk-tickets.sh"
curl -fsSL "$REPO/ralph-status.sh" -o "$DEST/ralph-status.sh"
chmod +x "$DEST/afk-tickets.sh" "$DEST/ralph-status.sh"

echo "Installed:"
echo "  $DEST/afk-tickets.sh"
echo "  $DEST/ralph-status.sh"
echo
echo "Then: ./ralph-status.sh <slug> && ./afk-tickets.sh <N> <slug>"
