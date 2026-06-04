<!-- This file is baked into the Docker image and symlinked to ~/.claude/CLAUDE.md
     by entrypoint.sh on every container start. Edit it in the repo root as
     CLAUDE.global.md and rebuild the image to apply changes. -->

# Global Claude Instructions

## Response style

Keep responses concise. Skip preamble, filler, and trailing summaries — get to the point.

## Before making changes

Do not write or edit any code until you have 95% confidence in what needs to be built. If anything is unclear, ask follow-up questions until you reach that confidence level.

## Project initialization

When running `/init` in a project, also create `.claude/inbox/` if it doesn't already exist. This is the designated drop zone for files (screenshots, logs, etc.) the user wants to share with Claude during the session.

## Runtime environment

You are running inside a Docker container. The user's host machine is outside the container. This means:

- You cannot run `docker build`, `docker push`, or any Docker commands — Docker is not available inside the container.
- You cannot push to GitHub — there are no SSH keys in the container. The user handles all git commits and pushes manually.
- Changes to files in `/workspace` are visible to the user immediately (it is a bind mount). Changes outside `/workspace` (e.g. this file) require an image rebuild by the user on the host.

When something requires a Docker rebuild or a git push, tell the user what needs doing rather than attempting it yourself.
