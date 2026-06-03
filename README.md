# claude-container

Run Claude Code isolated in a container. It will only have access to the current working directory.

## Usage: Build image once, then use docker-command (alias)

```sh
# In the same folder as the Dockerfile:
docker build -t claude-code:latest .
```
Create this alias in `.bashrc` or `.zshrc` or similar (modify or add ports as needed): 
```sh
alias claude-code='docker run --rm -it \
	-v "$PWD:/workspace" \
	-v claude-home:/home/node \
	-p 3000:3000 -p 8000:8000 \
	-w /workspace claude-code:latest'

```

## Status line

The image ships a status line that shows the model, context usage, and your
Claude.ai 5-hour / 7-day limit usage:

```
Opus 4.8 | Context: 84K/200K (42%) | 5h: 31% | 7d: 12%
```

`statusline.sh` is the canonical script (a `jq` one-liner that reads the status
JSON Claude Code sends on stdin). Because the `claude-home` volume shadows
`/home/node`, the script is baked into the image at `/opt/claude/statusline.sh`
and `entrypoint.sh` copies it into `~/.claude/statusline.sh` and registers it in
`~/.claude/settings.json` on first run. It then persists in the volume across
sessions, and you can edit your copy there freely (it won't be overwritten).

The `5h` / `7d` figures only appear for Claude.ai subscription logins, after the
first API response of the session.

## Updates

Claude Code is installed into the image via `npm`, but `/usr/local` is owned by
root and isn't on the `claude-home` volume, so it can't auto-update in place. To
get self-updating that *persists* across sessions, the entrypoint runs
`claude install` on first run, which puts a native install under
`~/.local/bin` (on the volume). The Dockerfile puts `~/.local/bin` ahead of the
npm copy on `PATH`, so that persisted, self-updating binary is the one that runs;
the npm copy only serves to bootstrap a fresh volume.

To pin a specific version instead, rebuild the image (`docker build` reinstalls
the latest from npm) and remove the `claude install` step from `entrypoint.sh`.
