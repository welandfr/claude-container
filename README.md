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

**3. Add an alias** to your `~/.bashrc`, `~/.zshrc`, or equivalent:

```sh
alias claude='docker run --rm -it \
	--name claude-container \
	-v "$PWD:/workspace:z" \
	-v claude-home:/home/node \
	-w /workspace \
	-p 127.0.0.1:3000:3000 \
	-p 127.0.0.1:8000:8000 \
	claude-code:latest'
```

Reload your shell (or `source` the file) to activate the alias.

---

### Windows

Requires Docker Desktop with the WSL2 backend enabled.

**1. Clone and build** — same as above. Use the `docker build` command directly; the build script requires a bash shell.

**2. Create `claude.bat`** and save it somewhere on your PATH. A good location that requires no admin access and is already on PATH on Windows 10/11:

```powershell
notepad $env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\claude.bat
```

Or create a personal scripts folder (e.g. `%USERPROFILE%\bin`), add it to your user PATH via *Settings → System → About → Advanced system settings → Environment Variables*, and place the file there.

Contents of `claude.bat`:

```bat
@echo off
docker run --rm -it ^
    --name claude-container ^
    -v "%CD%:/workspace" ^
    -v claude-home:/home/node ^
    -w /workspace ^
    -p 127.0.0.1:3000:3000 ^
    -p 127.0.0.1:8000:8000 ^
    claude-code:latest
```

Open a new terminal and `claude` will work from any directory.

---

## Usage

`cd` into a project directory and run `claude`:

```sh
my-project$ claude
```

To attach a shell to the running container:

```sh
docker exec -it claude-container /bin/bash
```

**Note:** The `-p` flags publish ports so you can reach dev servers running inside the container from your browser (e.g. a Node app on 3000, a FastAPI on 8000). They're bound to `127.0.0.1` so the services are only reachable from your own machine. Add or change ports to match what your projects use.

**Note:** The `claude-home` volume persists Claude's environment (login session, settings) across container runs.

---

## Global Claude instructions

`CLAUDE.global.md` in this repo is baked into the image and applied to every project as Claude's global `~/.claude/CLAUDE.md`. Edit it here and rebuild to update your preferences across all projects and machines.

---

## Updates

Claude Code is pinned to the version baked into the image and will tell you in-session when a newer one is out. To update, `cd` back into this repo and rebuild (see **Build the image** above).
