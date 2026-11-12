#!/usr/bin/env bash
# Launcher for the containerized Claude Code.
#
# Picks a container name derived from the current directory and a free block of
# host ports, so several instances can run side by side. All arguments are
# passed through to `claude` inside the container.
#
# Works with Docker or Podman (rootless or rootful).
#
# Env overrides:
#   CLAUDE_ENGINE       container CLI to use: docker or podman
#                       (default: docker if on PATH, else podman)
#   CLAUDE_IMAGE        image to run                      (default: claude-code:latest)
#   CLAUDE_PORTS        container ports to publish        (default: "3000 8000")
#   CLAUDE_PORT_OFFSET  use this offset instead of searching
#   CLAUDE_NO_PORTS=1   publish no ports at all
#   CLAUDE_NAME         use this container name
#   CLAUDE_PROFILE      account profile: selects the volume, prefixes the
#                       container name, tags the status line (default: none)
#   CLAUDE_HOME_VOLUME  volume holding ~/.claude  (default: claude-home[-<profile>])
set -euo pipefail

IMAGE=${CLAUDE_IMAGE:-claude-code:latest}
PROFILE=${CLAUDE_PROFILE:-}
# One volume per profile: ~/.claude lives there, so a separate volume means a
# separate login. An explicit CLAUDE_HOME_VOLUME still wins.
HOME_VOLUME=${CLAUDE_HOME_VOLUME:-claude-home${PROFILE:+-$PROFILE}}
MAX_OFFSET=${CLAUDE_MAX_OFFSET:-20}
read -r -a PORTS <<< "${CLAUDE_PORTS:-3000 8000}"

die()  { printf 'claude: %s\n' "$*" >&2; exit 1; }
warn() { printf 'claude: %s\n' "$*" >&2; }

# The profile becomes part of a docker volume name and a container name, so
# reject up front what docker would reject later with an opaque daemon error.
if [ -n "$PROFILE" ] && ! printf '%s' "$PROFILE" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9_.-]*$'; then
  die "invalid CLAUDE_PROFILE '$PROFILE' — letters, digits, '_', '.', '-' only, starting with a letter or digit"
fi

# --- container engine --------------------------------------------------------
# Docker first so existing setups are unchanged; podman when docker is absent.
# Identify podman by its version string rather than its name, so the
# podman-docker shim (a `docker` that is really podman) is handled too.
ENGINE=${CLAUDE_ENGINE:-}
if [ -z "$ENGINE" ]; then
  if command -v docker >/dev/null 2>&1; then ENGINE=docker
  elif command -v podman >/dev/null 2>&1; then ENGINE=podman
  else die "neither docker nor podman found on PATH"
  fi
fi
command -v "$ENGINE" >/dev/null 2>&1 || die "$ENGINE not found on PATH"
IS_PODMAN=0
if "$ENGINE" --version 2>/dev/null | grep -qi podman; then IS_PODMAN=1; fi

# --- container name ----------------------------------------------------------
# claude-[<profile>-]<current dir>, with -2, -3, ... appended if that name is
# taken. Named (rather than left anonymous) so `docker exec` can target a
# specific instance, and profile-first so `docker ps` groups by account.
name_taken() { "$ENGINE" ps -a --format '{{.Names}}' | grep -Fxq -- "$1"; }

name=${CLAUDE_NAME:-}
if [ -z "$name" ]; then
  slug=$(printf '%s' "${PWD##*/}" \
           | tr '[:upper:]' '[:lower:]' \
           | sed 's/[^a-z0-9_.-]/-/g; s/^[^a-z0-9]*//; s/-\{2,\}/-/g')
  base="claude${PROFILE:+-$PROFILE}-${slug:-workspace}"
  name=$base
  i=2
  while name_taken "$name"; do
    name="$base-$i"
    i=$((i + 1))
  done
fi

# --- host port offset --------------------------------------------------------
# Published ports hold a listening socket on the host (dockerd/docker-proxy, or
# podman's conmon/rootlessport/pasta), so enumerating
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

if [ "$IS_PODMAN" = 1 ]; then
  # Podman already maps host.containers.internal (and, from 5.x,
  # host.docker.internal) to the host; older podman rejects host-gateway.
  #
  # Rootless podman maps the host user to root inside the container, so the
  # bind-mounted project would be root-owned and unwritable for `node`. keep-id
  # maps the host user onto node's uid/gid instead (needs podman >= 4.3).
  # Rootful podman refuses keep-id and needs nothing: uids pass through as with
  # docker.
  if [ "$("$ENGINE" info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" = true ]; then
    args+=(--userns=keep-id:uid=1000,gid=1000)
  fi
else
  # Lets the container reach host services (e.g. a MySQL server) as
  # host.docker.internal; Docker Desktop provides it, Linux needs this.
  args+=(--add-host=host.docker.internal:host-gateway)
fi

# statusline.sh reads this from the container environment to tag the line with
# the account in use — it is not part of the status JSON Claude sends on stdin.
if [ -n "$PROFILE" ]; then
  args+=(-e "CLAUDE_PROFILE=$PROFILE")
fi

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
# Only worth a line when it is not the default — otherwise it is noise.
if [ "$HOME_VOLUME" != claude-home ]; then
  printf '        volume: %s\n' "$HOME_VOLUME"
fi

# Two launches racing for the same offset can still collide on `docker run`;
# re-running picks the next free block.
exec "$ENGINE" "${args[@]}"
