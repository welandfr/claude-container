# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker packaging of Claude Code that runs it isolated from the host. The container only ever sees the directory it's launched from (mounted at `/workspace`); a named `claude-home` volume persists `~/.claude` across runs. There is no application code here — the "product" is the image plus two shell scripts.

## Commands

```sh
# Build the image (run from repo root)
docker build -t claude-code:latest .

# Syntax-check the shell scripts (there is no test suite)
bash -n statusline.sh
bash -n entrypoint.sh

# Exercise the status line against a captured payload
echo '{"model":{"display_name":"Claude Opus 4.8"}, ...}' | ./statusline.sh
```

The image pins Claude Code to the version baked in at build time; updating means rebuilding.

## Architecture

Three files do the work, and their interaction is the thing to understand:

- **`Dockerfile`** — `node:22` base + dev tools. Claude Code is installed globally as **root** and left root-owned on purpose (a hardening choice: project code running as `node` cannot overwrite the binary, and `claude install`/volume auto-update were deliberately removed). `statusline.sh` is copied to the canonical path `/opt/claude/statusline.sh`, *outside* the volume.

- **`entrypoint.sh`** — runs on every container start. The `claude-home` volume mounts over `/home/node`, shadowing anything baked into the image there. So the entrypoint symlinks `~/.claude/statusline.sh` → `/opt/claude/statusline.sh` on each run (rebuilds propagate instantly; no stale per-volume copy), then merges a `statusLine` entry into `~/.claude/settings.json` with `jq` without clobbering other settings, and `exec`s `claude`.

  Key consequence: **edits to the status line must go through the repo + image rebuild.** A file written directly into the volume is not the source of truth and gets replaced by the symlink.

- **`statusline.sh`** — reads Claude's status JSON from stdin and prints one colored line (model, context usage, 5h/7d rate limits with reset countdowns). It is almost entirely a single `jq` program. The defensive comments there are load-bearing — read them before changing parsing:
  - `resets_at` is **epoch seconds (a number)** in the claude 2.x payload, though older paths may send an ISO string; `parse_iso` branches on `type` and treats anything unexpected as null. Indexing a non-string with `.[0:19]` throws *outside* `try/catch` and would blank the whole line.
  - The `rate_limits` block is absent until a Claude.ai subscription login gets its first API response — the script degrades to just model + context.
  - Empty/whitespace stdin (happens right after a model switch) is coerced to `{}` so the line never vanishes; a final bash fallback prints at least the model name if `jq` produces nothing.

## Conventions

- Anything that must survive the volume shadowing `/home/node` belongs in the image at a path outside the volume (the `/opt/claude` + system-wide `/etc/bash.bashrc` pattern), wired up by the entrypoint. Currently: `statusline.sh` and `CLAUDE.global.md` (the global `~/.claude/CLAUDE.md` applied to every project).
- Security posture is documented in `SECURITY_ASSESSMENT.md` and enforced by the run alias in `README.md`: non-root user, no Docker socket, no `--privileged`, ports bound to `127.0.0.1` only, and the rule to never launch from `$HOME` or any directory holding secrets (the launch dir is fully readable by the container).
