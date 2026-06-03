#!/usr/bin/env bash
# Container entrypoint: link the persisted ~/.claude volume to the status line,
# then hand off to Claude Code.
#
# ~/.claude is the `claude-home` Docker volume, which shadows anything baked into
# the image at that path. The canonical statusline.sh ships in the image at
# /opt/claude; the volume gets a symlink to it, refreshed on every run, so an
# image rebuild propagates to all containers immediately. The script is
# maintained in the repo and rebuilt — in-volume edits are not persisted.
set -e

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE="$CLAUDE_DIR/statusline.sh"

mkdir -p "$CLAUDE_DIR"

# Point the volume's status line at the canonical copy baked into the image.
# Re-created every run so image rebuilds take effect without a stale per-volume
# copy. Replaces any pre-existing real file left by older image versions.
ln -sfn /opt/claude/statusline.sh "$STATUSLINE"

# Register the status line in settings.json without clobbering other settings.
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi
if ! jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq --arg cmd "$STATUSLINE" \
     '.statusLine = {type: "command", command: $cmd, padding: 0}' \
     "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
fi

exec claude "$@"
