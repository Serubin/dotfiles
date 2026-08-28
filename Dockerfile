FROM debian:latest

# Bootstrap tools (chezmoi + externals), plus conveniences that make the container
# behave like a real terminal:
#   procps  -> working `ps`/`top`
#   locales -> UTF-8 (C.UTF-8) so the zsh prompt renders correctly
#   less    -> a pager for git/etc.
#   zsh     -> land in a login shell (also what chezmoi's package script installs)
#   neovim  -> skips run_once_before_20's slow source build; drop it to exercise
#              that path instead (Debian's nvim is older, but the harness tests
#              dotfiles config, not nvim)
# The chezmoi run_once package script installs the rest (tmux, gh, ...).
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl git sudo ca-certificates procps locales less zsh neovim && \
    rm -rf /var/lib/apt/lists/*

# Non-root user with passwordless sudo: matches a real machine and exercises the
# sudo package-install path (as root every `sudo` is a silent no-op). zsh login
# shell so a plain `docker compose exec debian zsh` works too.
ARG USER=dev
RUN useradd --create-home --shell /usr/bin/zsh "$USER" && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USER" && \
    chmod 0440 /etc/sudoers.d/"$USER"

# Install chezmoi into /usr/local/bin (on PATH for every user).
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

# One-command bootstrap: apply the mounted source, then drop into a login zsh.
COPY scripts/docker-test.sh /usr/local/bin/dotfiles-test
RUN chmod +x /usr/local/bin/dotfiles-test

USER dev
WORKDIR /home/dev
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color SHELL=/usr/bin/zsh

# Keep the container alive so you can `docker compose exec` into it repeatedly.
CMD ["sleep", "infinity"]
