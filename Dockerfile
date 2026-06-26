FROM ubuntu:24.04

# Prevent interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    tmux \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally
RUN npm install -g @anthropic-ai/claude-code

# Set up workspace
WORKDIR /workspace

# Copy in a default tmux config
COPY .tmux.conf /root/.tmux.conf

# Default command: start tmux session named "main"
CMD ["tmux", "new-session", "-s", "main"]
