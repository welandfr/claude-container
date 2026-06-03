FROM node:22-bookworm-slim

USER root

# Install tools commonly used for development
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    curl \
    wget \
    jq \
    less \
    nano \
    vim \
    unzip \
    zip \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Make Python command available
RUN ln -sf /usr/bin/python3 /usr/local/bin/python

# Status line: canonical copy lives outside the ~/.claude volume; the entrypoint
# seeds it into the volume on first run (see entrypoint.sh).
COPY statusline.sh /opt/claude/statusline.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /opt/claude/statusline.sh /usr/local/bin/entrypoint.sh

# Prefer a self-updating native install living on the claude-home volume
# (~/.local/bin) over the npm copy baked into the image. The npm copy stays as a
# bootstrap: the entrypoint runs `claude install` on a fresh volume, after which
# this PATH entry makes the persisted, self-updating binary win.
ENV PATH=/home/node/.local/bin:$PATH

WORKDIR /workspace

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
