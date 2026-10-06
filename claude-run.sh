#!/usr/bin/env bash
# Launcher for the containerized Claude Code.
#
# Picks a container name derived from the current directory and a free block of
# host ports, so several instances can run side by side. All arguments are
# passed through to `claude` inside the container.
#
# Env overrides:
#   CLAUDE_IMAGE        image to run                      (default: claude-code:latest)
#   CLAUDE_PORTS        container ports to publish        (default: "3000 8000")
#   CLAUDE_PORT_OFFSET  use this offset instead of searching
#   CLAUDE_NO_PORTS=1   publish no ports at all
#   CLAUDE_NAME         use this container name
#   CLAUDE_HOME_VOLUME  volume holding ~/.claude          (default: claude-home)
set -euo pipefail

IMAGE=${CLAUDE_IMAGE:-claude-code:latest}
HOME_VOLUME=${CLAUDE_HOME_VOLUME:-claude-home}
MAX_OFFSET=${CLAUDE_MAX_OFFSET:-20}
read -r -a PORTS <<< "${CLAUDE_PORTS:-3000 8000}"

die()  { printf 'claude: %s\n' "$*" >&2; exit 1; }
warn() { printf 'claude: %s\n' "$*" >&2; }

command -v docker >/dev/null 2>&1 || die "docker not found on PATH"

# --- container name ----------------------------------------------------------
# claude-<current dir>, with -2, -3, ... appended if that name is taken. Named
# (rather than left anonymous) so `docker exec` can target a specific instance.
name_taken() { docker ps -a --format '{{.Names}}' | grep -Fxq -- "$1"; }

name=${CLAUDE_NAME:-}
if [ -z "$name" ]; then
  slug=$(printf '%s' "${PWD##*/}" \
           | tr '[:upper:]' '[:lower:]' \
           | sed 's/[^a-z0-9_.-]/-/g; s/^[^a-z0-9]*//; s/-\{2,\}/-/g')
  base="claude-${slug:-workspace}"
  name=$base
  i=2
  while name_taken "$name"; do
    name="$base-$i"
    i=$((i + 1))
  done
fi

# --- host port offset --------------------------------------------------------
# Published docker ports hold a listening socket on the host, so enumerating
# listeners is enough to spot a block already claimed by another instance.
BUSY=""
BUSY_SOURCE=none
if command -v ss >/dev/null 2>&1; then
  BUSY=$(ss -ltn 2>/dev/null | awk 'NR>1 {n=split($4,a,":"); print a[n]}')
  BUSY_SOURCE=ss
elif command -v lsof >/dev/null 2>&1; then
  BUSY=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {n=split($9,a,":"); print a[n]}')
  BUSY_SOURCE=lsof
fi

port_busy() {
  if [ "$BUSY_SOURCE" = none ]; then
    # No ss/lsof: fall back to a connect test against the loopback address.
    (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&-; return 0; }
    return 1
  fi
  printf '%s\n' "$BUSY" | grep -Fxq -- "$1"
}

offset=""
if [ "${CLAUDE_NO_PORTS:-}" = 1 ] || [ ${#PORTS[@]} -eq 0 ]; then
  PORTS=()
elif [ -n "${CLAUDE_PORT_OFFSET:-}" ]; then
  offset=$CLAUDE_PORT_OFFSET
else
  for ((o = 0; o <= MAX_OFFSET; o++)); do
    free=1
    for p in "${PORTS[@]}"; do
      if port_busy $((p + o)); then free=0; break; fi
    done
    if [ "$free" = 1 ]; then offset=$o; break; fi
  done
  if [ -z "$offset" ]; then
    warn "no free port block in +0..+$MAX_OFFSET; starting without published ports"
    PORTS=()
  fi
fi

# --- run ---------------------------------------------------------------------
args=(run --rm -it
      --name "$name"
      -v "$PWD:/workspace:z"
      -v "$HOME_VOLUME:/home/node"
      -w /workspace)

mapping=""
for p in "${PORTS[@]}"; do
  args+=(-p "127.0.0.1:$((p + offset)):$p")
  mapping+=" $((p + offset))->$p"
done

args+=("$IMAGE" "$@")

if [ -n "$mapping" ]; then
  printf 'claude: %s  ports:%s\n' "$name" "$mapping"
else
  printf 'claude: %s  (no published ports)\n' "$name"
fi

# Two launches racing for the same offset can still collide on `docker run`;
# re-running picks the next free block.
exec docker "${args[@]}"
