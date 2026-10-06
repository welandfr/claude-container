# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker packaging of Claude Code that runs it isolated from the host. The container only ever sees the directory it's launched from (mounted at `/workspace`); a named `claude-home` volume persists `~/.claude` across runs. There is no application code here — the "product" is the image plus the shell scripts around it.

## Commands

```sh
# Build the image (run from repo root)
docker build -t claude-code:latest .

# Syntax-check the shell scripts (there is no test suite)
bash -n statusline.sh
bash -n entrypoint.sh
bash -n claude-run.sh

# Exercise the status line against a captured payload
echo '{"model":{"display_name":"Claude Opus 4.8"}, ...}' | ./statusline.sh
```

The image pins Claude Code to the version baked in at build time; updating means rebuilding.

## Architecture

The files that do the work, and their interaction, are the thing to understand:

- **`Dockerfile`** — `node:22` base + dev tools. Claude Code is installed globally as **root** and left root-owned on purpose (a hardening choice: project code running as `node` cannot overwrite the binary, and `claude install`/volume auto-update were deliberately removed). `statusline.sh` is copied to the canonical path `/opt/claude/statusline.sh`, *outside* the volume.

- **`entrypoint.sh`** — runs on every container start. The `claude-home` volume mounts over `/home/node`, shadowing anything baked into the image there. So the entrypoint symlinks `~/.claude/statusline.sh` → `/opt/claude/statusline.sh` on each run (rebuilds propagate instantly; no stale per-volume copy), then merges a `statusLine` entry into `~/.claude/settings.json` with `jq` without clobbering other settings, and `exec`s `claude`.

  Key consequence: **edits to the status line must go through the repo + image rebuild.** A file written directly into the volume is not the source of truth and gets replaced by the symlink.

- **`statusline.sh`** — reads Claude's status JSON from stdin and prints one colored line (optional account tag, model, context usage, 5h/7d rate limits with reset countdowns). It is almost entirely a single `jq` program. The defensive comments there are load-bearing — read them before changing parsing:
  - `resets_at` is **epoch seconds (a number)** in the claude 2.x payload, though older paths may send an ISO string; `parse_iso` branches on `type` and treats anything unexpected as null. Indexing a non-string with `.[0:19]` throws *outside* `try/catch` and would blank the whole line.
  - The `rate_limits` block is absent until a Claude.ai subscription login gets its first API response — the script degrades to just model + context.
  - Empty/whitespace stdin (happens right after a model switch) is coerced to `{}` so the line never vanishes; a final bash fallback prints at least the model name if `jq` produces nothing.
  - The account tag is the one field that does *not* come from the payload: it is `CLAUDE_PROFILE` read from the environment (the launcher passes it with `docker run -e`). It is therefore applied twice — in the `jq` program and again in that bash fallback, which runs precisely when the payload is unreadable and so must not drop the account.

- **`claude-run.sh`** / **`claude.ps1`** — the host-side launchers the user aliases to `claude`; they are what makes *multiple concurrent instances* work. Each derives a container name from the launch directory (`claude-<dir>`, suffixed `-2`, `-3`, … when `docker ps -a` already lists it) and shifts the published host ports to the next free block, so `--name` and `-p` never collide. Free ports are found by enumerating *listeners* (`ss`, else `lsof`, else a loopback connect test; `Get-NetTCPConnection` on Windows) — a published docker port always holds a host listening socket, which is what makes that check sufficient. Behaviour is overridable through `CLAUDE_PORTS`, `CLAUDE_NO_PORTS`, `CLAUDE_PORT_OFFSET`, `CLAUDE_NAME`, `CLAUDE_PROFILE`, `CLAUDE_IMAGE`, `CLAUDE_HOME_VOLUME` (documented in the README table). Two launches racing for the same offset can still lose to `docker run`; the fix is to re-run, not to lock.

  `CLAUDE_PROFILE=<name>` is the multi-account knob, and one variable deliberately drives all three identity surfaces: the volume (`claude-home-<name>` — a separate volume is a separate `~/.claude`, hence a separate login), the container-name prefix (`claude-<name>-<dir>`, profile first so `docker ps` groups by account), and the status-line tag (passed in with `-e`). It is validated against docker's name grammar up front, because an invalid one otherwise surfaces as an opaque daemon error. Unset reproduces the pre-profile behaviour byte for byte; an explicit `CLAUDE_HOME_VOLUME` overrides the derived volume.

  Within one profile, instances deliberately share its volume: one login, one set of settings, matching how parallel Claude Code sessions behave on a host. The entrypoint's `settings.json` merge is therefore run concurrently — it is write-only-if-absent and ends in an atomic `mv`, so a simultaneous first run is harmless.

## Conventions

- Anything that must survive the volume shadowing `/home/node` belongs in the image at a path outside the volume (the `/opt/claude` + system-wide `/etc/bash.bashrc` pattern), wired up by the entrypoint. Currently: `statusline.sh` and `CLAUDE.global.md` (the global `~/.claude/CLAUDE.md` applied to every project).
- Security posture is documented in `SECURITY_ASSESSMENT.md` and enforced by the launcher scripts: non-root user, no Docker socket, no `--privileged`, ports bound to `127.0.0.1` only, and the rule to never launch from `$HOME` or any directory holding secrets (the launch dir is fully readable by the container).
