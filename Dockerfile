FROM debian:latest

# Tools needed to bootstrap chezmoi + clone externals. The chezmoi run_once
# package script installs everything else (zsh, tmux, neovim, ...).
RUN apt-get update && \
    apt-get install -y curl git sudo ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install chezmoi into /usr/local/bin
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

WORKDIR /workspace
