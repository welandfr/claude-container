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

# Confirm the mounted directory with the user before handing off to Claude.
if [ -t 0 ]; then
  printf 'The current working directory will be accessible by Claude. Continue? [Y/n] '
  read -r reply
  case "$reply" in
    [Nn]*) echo "Aborted."; exit 1 ;;
  esac
fi

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE="$CLAUDE_DIR/statusline.sh"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
COMMANDS_DIR="$CLAUDE_DIR/commands"

mkdir -p "$CLAUDE_DIR"

# Point the volume's status line and global CLAUDE.md at canonical copies baked
# into the image. Re-created every run so image rebuilds take effect without a
# stale per-volume copy. Replaces any pre-existing real file left by older image versions.
ln -sfn /opt/claude/statusline.sh "$STATUSLINE"
ln -sfn /opt/claude/CLAUDE.md "$GLOBAL_CLAUDE_MD"

# Same for global slash commands, linked one file at a time so commands the user
# created directly in the volume are left alone.
mkdir -p "$COMMANDS_DIR"
for cmd in /opt/claude/commands/*.md; do
  [ -e "$cmd" ] && ln -sfn "$cmd" "$COMMANDS_DIR/$(basename "$cmd")"
done

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

# Give this volume its own SSH key for pushing to GitHub. It grants nothing until
# its public half is added to the agent's GitHub account, so each volume opts in
# separately. Instances share the volume and may race here: the hard link fails
# for all but one of them, so a simultaneous first run still ends with one key.
SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519_agent"
if [ ! -f "$SSH_KEY" ]; then
  mkdir -p -m 700 "$SSH_DIR"
  tmp=$(mktemp -d "$SSH_DIR/.keygen.XXXXXX")
  ssh-keygen -q -t ed25519 -N '' -C "claude-agent${CLAUDE_PROFILE:+-$CLAUDE_PROFILE}" -f "$tmp/key"
  if ln "$tmp/key" "$SSH_KEY" 2>/dev/null; then
    mv "$tmp/key.pub" "$SSH_KEY.pub"
    printf '\nNew SSH key for this volume. To allow git push, add it to the agent GitHub account:\n\n%s\n\n' "$(cat "$SSH_KEY.pub")"
    printf 'Show it again with: cat ~/.ssh/id_ed25519_agent.pub\n'
    # Claude's interface takes over the terminal next, so hold the key on screen.
    if [ -t 0 ]; then
      printf 'Press Enter to continue. '
      read -r _
    fi
  fi
  rm -rf "$tmp"
fi

exec claude "$@"
