# Base images are fully qualified (docker.io/...) because podman/buildah refuse
# or prompt on unqualified short names; docker accepts either form.
FROM docker.io/library/node:22-bookworm-slim

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

# PHP 8.4 from the sury.org repo (bookworm itself only ships 8.2), with
# pdo_mysql (php8.4-mysql), pdo_sqlite (php8.4-sqlite3) and the extensions
# Composer packages commonly need.
RUN curl -fsSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/sury-php.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ bookworm main" \
      > /etc/apt/sources.list.d/sury-php.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    php8.4-cli \
    php8.4-mysql \
    php8.4-sqlite3 \
    php8.4-mbstring \
    php8.4-xml \
    php8.4-curl \
    php8.4-zip \
    php8.4-intl \
 && rm -rf /var/lib/apt/lists/*
COPY --from=docker.io/library/composer:2 /usr/bin/composer /usr/local/bin/composer

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Make Python command available
RUN ln -sf /usr/bin/python3 /usr/local/bin/python

# Shell convenience aliases. Written to /etc/bash.bashrc (system-wide, outside
# the claude-home volume) so they survive the volume shadowing /home/node.
RUN echo "alias ll='ls -lha'" >> /etc/bash.bashrc

# Status line, global CLAUDE.md and slash commands: canonical copies live outside
# the ~/.claude volume; the entrypoint symlinks them into the volume on every run
# (see entrypoint.sh).
COPY statusline.sh /opt/claude/statusline.sh
COPY CLAUDE.global.md /opt/claude/CLAUDE.md
COPY commands/ /opt/claude/commands/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY php-serve.sh /usr/local/bin/php-serve
RUN chmod +x /opt/claude/statusline.sh /usr/local/bin/entrypoint.sh /usr/local/bin/php-serve

# GitHub SSH: which key to use, and GitHub's pinned host key (from
# https://api.github.com/meta), so the first push doesn't have to trust on first
# use. The key itself is per-volume, created by the entrypoint.
COPY ssh_config /etc/ssh/ssh_config.d/claude-agent.conf
RUN echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" >> /etc/ssh/ssh_known_hosts

# Fail a commit in a repo with no identity, instead of guessing one from the
# hostname. The author is chosen per project in the repo's own config.
RUN git config --system user.useConfigOnly true

WORKDIR /workspace

USER node

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
