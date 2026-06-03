#!/usr/bin/env bash
# Container entrypoint: seed the persisted ~/.claude volume with the status line,
# then hand off to Claude Code.
#
# ~/.claude is the `claude-home` Docker volume, which shadows anything baked into
# the image at that path. So the canonical statusline.sh ships in the image at
# /opt/claude and is copied into the volume on first run; later runs leave the
# user's (possibly edited) copy untouched.
set -e

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE="$CLAUDE_DIR/statusline.sh"

mkdir -p "$CLAUDE_DIR"

# Seed the status line script if the volume doesn't have one yet.
if [ ! -f "$STATUSLINE" ]; then
  cp /opt/claude/statusline.sh "$STATUSLINE"
  chmod +x "$STATUSLINE"
fi

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

# Bootstrap a self-updating native install into the volume on first run, using
# the npm copy baked into the image. Once present, PATH (set in the Dockerfile)
# makes ~/.local/bin/claude win and it keeps itself updated. Non-fatal if the
# install can't reach the network — we just fall back to the npm copy.
if [ ! -x "$HOME/.local/bin/claude" ]; then
  claude install >/dev/null 2>&1 || true
fi

exec claude "$@"
