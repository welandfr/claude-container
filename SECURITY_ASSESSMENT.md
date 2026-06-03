# Security Assessment: Dockerized Claude Code Environment

**Date:** 2026-06-03  
**Scope:** Container isolation, host filesystem access, privilege escalation vectors

---

## Summary

No direct container escape paths exist in this setup — no Docker socket mount, no `--privileged` flag, no host network/PID/IPC sharing. Claude Code cannot access local files beyond `/workspace`.

**Confirmed absent (the most critical escape vectors):**
- No `/var/run/docker.sock` mount
- No `--privileged` flag
- No `--network host`, `--pid host`, or `--ipc host`
- No `--cap-add SYS_ADMIN` or dangerous capability additions
- Container runs as non-root `node` user
- No command injection in `entrypoint.sh` or `statusline.sh`

---

## Fixed

- **CWD boundary warning** — README now warns never to invoke from `$HOME` or credential-containing directories.
- **Localhost-only ports** — Port bindings restricted to `127.0.0.1`, preventing network exposure of container services.
- **Hardened claude binary** — Removed `claude install` and volume-based auto-update; binary is now root-owned in the image and cannot be overwritten by project code.

## No open issues remain.
