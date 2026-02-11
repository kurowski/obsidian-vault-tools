FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    curl \
    git \
    gh \
    ripgrep \
    fzf \
    jq \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m claude
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/claude/.local/bin:$PATH"
WORKDIR /workspace
CMD ["sleep", "infinity"]
