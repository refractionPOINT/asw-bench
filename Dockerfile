FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    git \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Claude Code and OpenAI CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install LimaCharlie CLI (ticket-cli branch) and Claude Agent SDK
RUN pip3 install --break-system-packages --no-cache-dir \
    claude-agent-sdk \
    git+https://github.com/refractionPOINT/python-limacharlie.git@feat/ticket-cli

# Install Claude Code CLI (Anthropic)
RUN npm install -g @anthropic-ai/claude-code

# Install Codex CLI (OpenAI)
RUN npm install -g @openai/codex

# Install Gemini CLI (Google)
RUN npm install -g @google/gemini-cli

# Use the existing ubuntu user (uid 1000) to match typical host file ownership.
# Required by claude --dangerously-skip-permissions which refuses to run as root.
ENV HOME=/home/ubuntu

# Clone LimaCharlie documentation
RUN git clone --branch ticketing --single-branch --depth 1 \
    https://github.com/refractionPOINT/documentation.git /docs/limacharlie

# Copy scenarios into the container
COPY scenarios/ /scenarios/

# Copy the entrypoint
COPY harness/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER ubuntu
ENTRYPOINT ["/entrypoint.sh"]
