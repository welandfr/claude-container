# Containerized Claude Code

Run Claude Code inside a Docker container, isolated from the rest of your machine. The container can only see the directory you launch it from.

> **Security:** The directory you start in is the *only* thing the container can access. Never launch from `$HOME` or any folder holding credentials, SSH keys, or other secrets — launch from a dedicated project directory.

---

## Setup

### Linux / macOS

**1. Clone this repo** and `cd` into it.

```sh
git clone https://github.com/welandfr/claude-container
cd claude-container
```

**2. Build the image**

```sh
docker build -t claude-code:latest .
```

Or use the included build script:

```sh
./build.sh
```

**3. Add an alias** to your `~/.bashrc`, `~/.zshrc`, or equivalent, pointing at the launcher script in this repo:

```sh
alias claude='/path/to/claude-container/claude-run.sh'
```

Reload your shell (or `source` the file) to activate the alias.

---

### Windows (PowerShell)

Requires Docker Desktop with the WSL2 backend enabled.

**1. Clone and build** — same as above. Use the `docker build` command directly; the build script requires a bash shell.

```powershell
git clone https://github.com/welandfr/claude-container
cd claude-container
docker build -t claude-code:latest .
```

**2. Add a function to your PowerShell profile** pointing at `claude.ps1` in this repo:

```powershell
notepad $PROFILE
```

```powershell
function claude { & "C:\path\to\claude-container\claude.ps1" @args }
```

If the script is blocked when you first run it, allow local scripts for your user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Open a new terminal and `claude` will work from any directory.

---

## Usage

`cd` into a project directory and run `claude`:

```sh
my-project$ claude
claude: claude-my-project  ports: 3000->3000 8000->8000
```

Any arguments are passed through to Claude Code inside the container (`claude --resume`, `claude -p "..."`, and so on).

### Running several instances at once

Open a new terminal, `cd` into another project, and run `claude` again — the launcher keeps instances from colliding:

- **Container name** is derived from the directory (`claude-my-project`), with `-2`, `-3`, … appended if that name is already running.
- **Host ports** are shifted to the next free block. Inside the container your dev server still listens on 3000; the host reaches the second instance on 3001, the third on 3002, and so on. The mapping is printed on startup.

```sh
proj-a$ claude
claude: claude-proj-a  ports: 3000->3000 8000->8000

proj-b$ claude
claude: claude-proj-b  ports: 3001->3000 8001->8000
```

All instances share the `claude-home` volume, so they share one login and one set of settings — as parallel Claude Code sessions on a host do.

### Attaching a shell

List what's running, then exec into the one you want:

```sh
docker ps --format '{{.Names}}\t{{.Ports}}'
docker exec -it claude-my-project /bin/bash
```

### Ports

The launcher publishes container ports 3000 and 8000 by default, bound to `127.0.0.1` so the services are only reachable from your own machine. Override per project or globally with environment variables:

| Variable | Effect |
| --- | --- |
| `CLAUDE_PORTS` | Space-separated container ports to publish (default `"3000 8000"`), e.g. `CLAUDE_PORTS="5173 8080" claude` |
| `CLAUDE_NO_PORTS=1` | Publish nothing |
| `CLAUDE_PORT_OFFSET` | Pin the offset instead of searching for a free block |
| `CLAUDE_NAME` | Pin the container name |
| `CLAUDE_IMAGE` | Run a different image tag (default `claude-code:latest`) |
| `CLAUDE_HOME_VOLUME` | Use a different volume for `~/.claude` (default `claude-home`) |

**Note:** The `claude-home` volume persists Claude's environment (login session, settings) across container runs.

---

## Global Claude instructions

`CLAUDE.global.md` in this repo is baked into the image and applied to every project as Claude's global `~/.claude/CLAUDE.md`. Edit it here and rebuild to update your preferences across all projects and machines.

---

## Updates

Claude Code is pinned to the version baked into the image and will tell you in-session when a newer one is out. To update, `cd` back into this repo and rebuild (see **Build the image** above).
