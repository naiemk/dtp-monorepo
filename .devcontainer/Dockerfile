FROM mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    python3-full \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create and activate a Python virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Node package managers
RUN npm install -g yarn \
    && npm install -g hardhat \
    && curl -fsSL https://bun.sh/install | bash

# Set up custom prompt
RUN echo 'export PS1="\[\033[1;36m\]\w\[\033[0m\] \[\033[1;32m\]\$(git branch 2>/dev/null | sed -n "s/^\* \(.*\)/\1/p")\[\033[0m\] \[\033[1;33m\]➜\[\033[0m\] "' >> /root/.bashrc

# Set working directory
WORKDIR /workspace
