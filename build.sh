#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-claude-code:latest}"

# Same engine choice as claude-run.sh: CLAUDE_ENGINE, else docker, else podman.
ENGINE=${CLAUDE_ENGINE:-}
if [ -z "$ENGINE" ]; then
  if command -v docker >/dev/null 2>&1; then ENGINE=docker
  elif command -v podman >/dev/null 2>&1; then ENGINE=podman
  else echo "build: neither docker nor podman found on PATH" >&2; exit 1
  fi
fi

"$ENGINE" build -t "$IMAGE" "$(dirname "$0")"
echo "Built $IMAGE with $ENGINE"
