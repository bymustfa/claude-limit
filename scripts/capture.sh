#!/bin/bash
# Claude Code status line command: records weekly/5h limit snapshots, prints a short status.
# Shared folder: iCloud Drive when available, so every machine on the account contributes.
# Each machine appends to its own file (snapshots-<host>.jsonl); the app merges them all.
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
if [ -n "$CLAUDE_LIMIT_DIR" ]; then DIR="$CLAUDE_LIMIT_DIR"
elif [ -d "$ICLOUD" ]; then DIR="$ICLOUD/claude-limit"
else DIR="$HOME/.claude-limit"; fi
FILE="$DIR/snapshots-$(hostname -s).jsonl"
input=$(cat)

key=$(printf '%s' "$input" | /usr/bin/jq -c 'select(.rate_limits.seven_day != null) | {
  five_hour: (if .rate_limits.five_hour then {pct: .rate_limits.five_hour.used_percentage, resets_at: .rate_limits.five_hour.resets_at} else null end),
  seven_day: {pct: .rate_limits.seven_day.used_percentage, resets_at: .rate_limits.seven_day.resets_at}
}' 2>/dev/null)

if [ -z "$key" ]; then
  echo "7d: –"
  exit 0
fi

mkdir -p "$DIR"
last=$(tail -n 1 "$FILE" 2>/dev/null | /usr/bin/jq -c 'del(.t)' 2>/dev/null)
if [ "$key" != "$last" ]; then
  printf '%s\n' "$(printf '%s' "$key" | /usr/bin/jq -c --argjson t "$(date +%s)" '{t: $t} + .')" >> "$FILE"
fi
echo "7d: $(printf '%s' "$key" | /usr/bin/jq -r '.seven_day.pct')%"
