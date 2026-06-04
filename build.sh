#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-claude-code:latest}"

docker build -t "$IMAGE" "$(dirname "$0")"
echo "Built $IMAGE"
