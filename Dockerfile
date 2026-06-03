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

# Shell convenience aliases. Written to /etc/bash.bashrc (system-wide, outside
# the claude-home volume) so they survive the volume shadowing /home/node.
RUN echo "alias ll='ls -lha'" >> /etc/bash.bashrc

# Status line: canonical copy lives outside the ~/.claude volume; the entrypoint
# seeds it into the volume on first run (see entrypoint.sh).
COPY statusline.sh /opt/claude/statusline.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /opt/claude/statusline.sh /usr/local/bin/entrypoint.sh


WORKDIR /workspace

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
