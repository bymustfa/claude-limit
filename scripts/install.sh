#!/bin/bash
# Installs the status line capture script to ~/.claude-limit/
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p "$HOME/.claude-limit"
cp scripts/capture.sh "$HOME/.claude-limit/capture.sh"
chmod +x "$HOME/.claude-limit/capture.sh"
# Move an existing local snapshot file into the shared folder (once).
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
if [ -d "$ICLOUD" ] && [ -f "$HOME/.claude-limit/snapshots.jsonl" ]; then
  mkdir -p "$ICLOUD/claude-limit"
  mv -n "$HOME/.claude-limit/snapshots.jsonl" "$ICLOUD/claude-limit/snapshots-$(hostname -s).jsonl"
fi
echo "Installed. Set statusLine.command to: $HOME/.claude-limit/capture.sh"
