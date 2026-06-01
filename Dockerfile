FROM node:22-bookworm-slim

USER root

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
    vim \
    unzip \
    zip \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Make Python command available
RUN ln -sf /usr/bin/python3 /usr/local/bin/python

WORKDIR /workspace

USER node

ENTRYPOINT ["claude"]