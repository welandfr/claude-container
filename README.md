# claude-container

Run Claude Code inside a Docker container, isolated from the rest of your machine. The container can only see the directory you launch it from.

> **Security:** The directory you start in is the *only* thing the container can access. Never launch from `$HOME` or any folder holding credentials, SSH keys, or other secrets — launch from a dedicated project directory.

## Setup

**1. Build the image** (run once, from the folder containing the `Dockerfile`):

```sh
docker build -t claude-code:latest .
```

**2. Add an alias** to your `~/.bashrc`, `~/.zshrc`, or equivalent:

```sh
alias claude-code='docker run --rm -it \
	-v "$PWD:/workspace" \
	-v claude-home:/home/node \
	-w /workspace \
	-p 127.0.0.1:3000:3000 -p 127.0.0.1:8000:8000 \
	claude-code:latest'
```
**Note:** The `-p` flags publish ports so you can reach dev servers running *inside* the container from your browser (e.g. a Node app on 3000, an API on 8000) — without them, those ports stay trapped in the container. They're bound to `127.0.0.1` so the services are reachable only from your own machine, not the local network. **Add or change ports to match what your projects use.**

Reload your shell (or `source` the file).

## Usage

`cd` into a project and run:

```sh
claude-code
```

## Updates

Claude Code is pinned to the version baked into the image and will tell you in-session when a newer one is out. To update, `cd` back into the folder containing the `Dockerfile` and rebuild the image:

```sh
docker build -t claude-code:latest .
```
