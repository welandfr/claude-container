# Security Assessment: Dockerized Claude Code Environment

**Date:** 2026-06-03  
**Scope:** Container isolation, host filesystem access, privilege escalation vectors

---

## Summary

No direct container escape paths exist in this setup — no Docker socket mount, no `--privileged` flag, no host network/PID/IPC sharing. Claude Code cannot access local files beyond `/workspace`. Two open issues remain that trade auto-update convenience against security hardening.

**Confirmed absent (the most critical escape vectors):**
- No `/var/run/docker.sock` mount
- No `--privileged` flag
- No `--network host`, `--pid host`, or `--ipc host`
- No `--cap-add SYS_ADMIN` or dangerous capability additions
- Container runs as non-root `node` user
- No command injection in `entrypoint.sh` or `statusline.sh`

---

## Open Issues

### Issue 1 — CWD is the Entire Security Boundary

**File:** README.md | **Severity:** HIGH | **Status:** Mitigated (warning added)

The alias mounts `$PWD` into `/workspace`. The isolation boundary is entirely determined by which directory is active at invocation time. Invoking from `$HOME` or any directory containing credentials gives the container full read/write access to that tree.

A warning has been added to the README. The underlying design is inherent to the tool's purpose and cannot be further hardened at the container level.

**Required user action:** Always invoke from a dedicated project directory, never from `$HOME` or any directory containing sensitive files.

---

### Issue 2 — Persistent Home Volume Enables Cross-Session Binary Persistence

**File:** entrypoint.sh, Dockerfile | **Severity:** MEDIUM | **Status:** Fixed

`claude install` previously ran on first container start, installing a self-updating native binary to `~/.local/bin/claude` on the `claude-home` named volume. Any code executing inside the container could overwrite that binary with a malicious replacement affecting all future sessions. The binary also auto-updated from Anthropic's CDN with no checksum verification.

**Fix applied:** Removed the `claude install` step from `entrypoint.sh` and the `PATH` override from the Dockerfile. Claude Code now runs from the npm-pinned binary baked into the image at build time, which is owned by root and not writable by the `node` user. Claude Code's built-in update notifications alert to new versions; updating requires `docker build`.

---

### Issue 3 — Port Bindings

**File:** README.md | **Severity:** MEDIUM | **Status:** Fixed

Port bindings changed from `0.0.0.0` to `127.0.0.1`, restricting dev servers and MCP servers started inside the container to localhost only.

---

## No open issues remain.
