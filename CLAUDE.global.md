<!-- This file is baked into the Docker image and symlinked to ~/.claude/CLAUDE.md
     by entrypoint.sh on every container start. Edit it in the repo root as
     CLAUDE.global.md and rebuild the image to apply changes. -->

# Global Claude Instructions

## Response style

Keep responses concise. Skip preamble, filler, and trailing summaries — get to the point.

## Before making changes

Do not write or edit any code until you have 95% confidence in what needs to be built. If anything is unclear, ask follow-up questions until you reach that confidence level.

## Runtime environment

You are running inside a Docker container. The user's host machine is outside the container. This means:

- You cannot run `docker build`, `docker push`, or any Docker commands — Docker is not available inside the container.
- Git commits are fine as long as the user asks you to do it. You may push to repos where the agent GitHub account is a collaborator, only when asked; confirm before pushing tags. If a push is rejected for lack of access, tell the user rather than working around it — they may need to add this volume's key (`~/.ssh/id_ed25519_agent.pub`) or invite the account.
- Before committing, check `git config --local user.email`. If it is not set, ask the user which identity to use as author for this project, then set it with `git config --local user.name` and `user.email`. Never set an identity globally: git is configured to refuse commits with no identity, so that the question gets asked.
- Container ports 3000 and 8000 are published to the host (possibly shifted, e.g. 8001). Dev servers must bind `0.0.0.0`, not `localhost`, to be reachable. For PHP, use `php-serve [docroot] [port]` (PHP 8.4 built-in server, default port 8000).
- Changes to files in `/workspace` are visible to the user immediately (it is a bind mount). Changes outside `/workspace` (e.g. this file) require an image rebuild by the user on the host.

When something requires a Docker rebuild, tell the user what needs doing rather than attempting it yourself.
