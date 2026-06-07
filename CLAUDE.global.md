<!-- This file is baked into the Docker image and symlinked to ~/.claude/CLAUDE.md
     by entrypoint.sh on every container start. Edit it in the repo root as
     CLAUDE.global.md and rebuild the image to apply changes. -->

# Global Claude Instructions

## Response style

Keep responses concise. Skip preamble, filler, and trailing summaries — get to the point.

## Before making changes

Do not write or edit any code until you have 95% confidence in what needs to be built. If anything is unclear, ask follow-up questions until you reach that confidence level.

## User uploads

When the user refers to a screenshot, image, file, or upload without specifying a path, look in `~/claude-inbox/` and use the most recently modified file there.

## Runtime environment

You are running inside a Docker container. The user's host machine is outside the container. This means:

- You cannot run `docker build`, `docker push`, or any Docker commands — Docker is not available inside the container.
- You cannot push to GitHub — there are no SSH keys in the container. Git commits are fine; the user handles all pushes manually from the host.
- Before committing, check if `git config --global user.name` is set. If not, check the last commit author with `git log -1 --format='%an <%ae>'` and ask the user to confirm using that identity. If there is no git history, ask the user to provide their name and email. Once confirmed, set it with `git config --global` so it persists.
- Changes to files in `/workspace` are visible to the user immediately (it is a bind mount). Changes outside `/workspace` (e.g. this file) require an image rebuild by the user on the host.

When something requires a Docker rebuild or a git push, tell the user what needs doing rather than attempting it yourself.
