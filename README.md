# Serubin's Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and a simple install script. Each tool lives in its own directory with optional per-OS setup scripts.

## Installation

```bash
git clone https://github.com/Serubin/dotfiles.git .dotfiles && cd .dotfiles && ./install.sh
```

Re-run `./install.sh` to update. Add `-v` for verbose output. Use `--uninstall` to remove symlinks (installed packages are left in place).

### Supported Platforms

- macOS (Homebrew)
- Debian / Ubuntu (apt)

The install script uses `sudo` for package installation.

### Docker Testing

A Dockerfile and docker-compose config are included for testing on Debian:

```bash
docker compose up -d && docker compose exec debian bash
# Inside the container:
./install.sh
```

## What's Included

| Tool | Directory | Stow Target | Description |
|------|-----------|-------------|-------------|
| Git | `git/` | `$HOME` | Config, aliases, GPG signing, global gitignore |
| Zsh | `zsh/` | `$HOME` | Modular shell config, plugins via zinit, custom prompt |
| tmux | `tmux/` | `$HOME` | 256-color config, TPM plugins, session restore |
| Neovim | `nvim/` | `$HOME/.config/` | Lua config with lazy.nvim plugin manager |

## Repository Layout

```
.dotfiles/
├── install.sh                 # Main install/uninstall script
├── setup/                     # Global setup (installs stow)
│   ├── debian
│   └── darwin
├── git/
│   ├── .gitconfig             # Aliases, GPG signing, editor, pull.rebase
│   ├── .gitignore_global
│   └── setup/
├── zsh/
│   ├── .zshrc                 # Sources all files in ~/.zsh/
│   ├── .zsh/
│   │   ├── 00-os              # OS detection ($DISTRO)
│   │   ├── 01-brew            # Homebrew path setup
│   │   ├── 02-zinit           # Zinit plugin manager
│   │   ├── alias              # Shell aliases
│   │   ├── env                # Environment, keybindings, completion, history
│   │   ├── function           # Helper functions (mk, cdls, _cache_completion)
│   │   ├── jump-target        # Jump target config
│   │   ├── promptrc           # Prompt loader
│   │   └── prompt/            # Custom prompt theme
│   └── setup/
├── tmux/
│   ├── .tmux.conf             # Colors, keybindings, TPM plugins
│   └── setup/
├── nvim/
│   └── nvim/
│       ├── init.lua            # Entry point (loads lazy.nvim)
│       ├── lua/config/         # Options, keymaps
│       └── lua/plugins/        # Plugin specs (neo-tree, solarized, blink, etc.)
├── Dockerfile                  # Debian test image
└── docker-compose.yml
```

## How It Works

### Stow

Each top-level directory is a stow package. Running `stow git` from the repo root symlinks `git/.gitconfig` to `~/.gitconfig`, `git/.gitignore_global` to `~/.gitignore_global`, and so on. The `setup/` subdirectory within each package is ignored by stow (`--ignore setup`).

Most packages stow into `$HOME`. Neovim is the exception — it stows into `$HOME/.config/` so that `nvim/nvim/` maps to `~/.config/nvim/`.

### Install Script

`install.sh` does the following for each tool:

1. Detects the OS (macOS or Debian/Ubuntu)
2. Runs global setup (`setup/$DISTRO`) to install stow
3. For each tool: unstow (clean), re-stow (symlink), then run `setup/$DISTRO` and `setup/common` if they exist

### Per-OS Setup Scripts

Each tool can provide setup scripts in its `setup/` directory:

- `setup/debian` — Debian/Ubuntu-specific install (apt)
- `setup/darwin` — macOS-specific install (brew)
- `setup/common` — Shared setup (e.g., cloning plugin managers)

## Tool Details

### Git

- Aliases: `g s` (status), `g l` (pretty log), `g ap` (add -p), `g co` (checkout), `g br` (branch)
- GPG commit signing enabled
- `pull.rebase = true`
- Editor set to `nvim`

### Zsh

`.zshrc` sources every file in `~/.zsh/` in lexicographic order (00-os, 01-brew, 02-zinit, alias, env, ...), making it easy to add or reorder config.

**Plugins** (via [zinit](https://github.com/zdharma-continuum/zinit)):
- `zsh-syntax-highlighting` — command highlighting
- `zsh-autosuggestions` — fish-like suggestions
- `zsh-jump-target` — quick directory jumping
- `dircolors-solarized` — solarized color scheme for `ls`

**Notable aliases**: `vim` → `nvim`, `cd` → `cdls` (auto-ls after cd), `_` → `sudo`, `extract` → `aunpack`

**Customization**: Add personal overrides to `~/.custom` (sourced at the end of `.zshrc`). A template is provided at `zsh/setup/.custom`.

### tmux

- 256-color terminal with blue status bar
- 1-based window/pane indexing
- `prefix + \` / `prefix + -` for horizontal/vertical splits (preserves working directory)
- Session auto-save every 5 minutes and auto-restore on start

**Plugins** (via [TPM](https://github.com/tmux-plugins/tpm)):
- `tmux-sensible` — sensible defaults
- `tmux-prefix-highlight` — visual prefix indicator
- `tmux-resurrect` — session save/restore
- `tmux-continuum` — automatic session saving

### Neovim

Lua-based configuration using [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management.

**Plugins**:
- `neo-tree` — file explorer
- `solarized` — color scheme
- `blink` — cursor effects
- `better-whitespace` — trailing whitespace highlighting
- `snacks` — UI utilities

## License

MIT — see [LICENSE](LICENSE).
