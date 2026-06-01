FROM node:22-bookworm-slim

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace
USER node

ENTRYPOINT ["claude"]