# Serubin's Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/). The chezmoi
source lives under [`home/`](home/) (set via [`.chezmoiroot`](.chezmoiroot));
repo tooling (this README, `Dockerfile`, `.spr.yml`) stays at the top level.

## Installation

### New machine

One command — installs chezmoi (if needed), then inits + applies:

```bash
sh -c "$(curl -fsLS https://raw.githubusercontent.com/Serubin/dotfiles/main/install.sh)"
```

Or from a local clone (`./install.sh` uses the checkout as the source):

```bash
git clone https://github.com/Serubin/dotfiles.git && dotfiles/install.sh
```

Or drive chezmoi directly without the wrapper:

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" && chezmoi init --apply Serubin/dotfiles
```

`chezmoi init` prompts once for your git name/email/signingkey (press Enter to
accept defaults), clones the plugin managers, installs packages for your OS, and
writes the managed files into `$HOME`.

### Migrating an existing machine from the old GNU Stow setup

This repo previously used GNU Stow. To switch a machine over:

```bash
brew install chezmoi                                  # or: sh -c "$(curl -fsLS get.chezmoi.io)"
chezmoi init --source="$HOME/.dotfiles"               # use this checkout as the source
chezmoi diff                                          # PREVIEW every change first
chezmoi apply                                         # applies; auto-removes legacy Stow symlinks
```

The first `apply` runs a `run_once_before` hook that removes the old Stow
symlinks (only symlinks pointing into `.dotfiles`; real files are untouched).
You can also run it manually beforehand: [`scripts/uninstall-stow.sh`](scripts/uninstall-stow.sh).

> **Review the diff.** `chezmoi apply` overwrites managed paths. In particular
> `~/.claude/CLAUDE.md` may differ from the repo copy — confirm via `chezmoi diff`
> before applying.

### Supported platforms

- macOS (Homebrew)
- Debian / Ubuntu (apt; Neovim via Homebrew if present, else built from source)

Package installs use `sudo` on Linux.

## Day-to-day workflow

chezmoi manages **copies**, not symlinks — editing `~/.zshrc` directly does *not*
update the repo. Instead:

```bash
chezmoi edit ~/.zshrc        # edit the source for a file, then apply
chezmoi apply                # write pending changes into $HOME
chezmoi diff                 # preview pending changes
chezmoi cd                   # drop into the source dir (home/) to edit/commit
chezmoi re-add               # pull live edits of already-managed files back into the source
chezmoi update               # git pull the source + apply
```

## What's included

| Tool | Target | Description |
|------|--------|-------------|
| Git | `~/.gitconfig`, `~/.gitignore_global` | Aliases, templated identity, global ignore |
| Zsh | `~/.zshrc`, `~/.zshenv`, `~/.zsh/` | Modular config, zinit plugins, custom prompt |
| tmux | `~/.tmux.conf` | 256-color, TPM plugins, session restore |
| Neovim | `~/.config/nvim/` | Lua config with lazy.nvim |
| Claude Code | `~/.claude/` (curated) | CLAUDE.md, settings.json, statusline, skills, plugin config |

## Repository layout

```
.dotfiles/
├── .chezmoiroot                      # → home   (chezmoi source root)
├── home/
│   ├── .chezmoi.toml.tmpl            # init prompts (git identity)
│   ├── .chezmoiignore                # runtime/secret paths chezmoi must not manage
│   ├── .chezmoiexternal.toml.tmpl    # zinit, tpm, gitstatus (cloned & auto-updated)
│   ├── .chezmoiscripts/
│   │   ├── run_once_before_10-uninstall-stow.sh
│   │   └── run_once_after_20-install-packages.sh.tmpl
│   ├── dot_gitconfig.tmpl
│   ├── dot_gitignore_global
│   ├── dot_zshenv  dot_zshrc
│   ├── dot_zsh/                      # 00-os 01-brew executable_02-zinit alias env function promptrc prompt/
│   ├── dot_tmux.conf
│   ├── create_dot_custom             # ~/.custom (created once, never overwritten)
│   ├── dot_config/nvim/
│   └── dot_claude/                   # CURATED: CLAUDE.md, settings.json, statusline, skills/, plugins/*.json
├── scripts/uninstall-stow.sh         # remove legacy Stow symlinks (manual)
├── Dockerfile  docker-compose.yml    # Debian test harness
├── LICENSE  .spr.yml  README.md
```

## How it works

- **Source naming.** chezmoi maps source names to targets: `dot_` → `.`,
  `executable_` → `+x`, `create_` → create-if-absent, `private_` → `0600`,
  `*.tmpl` → Go-templated. OS differences are handled by templates
  (`.chezmoi.os`, `.chezmoi.osRelease.id`).
- **Externals.** zinit, tpm, and (on Linux) gitstatus are declared in
  `.chezmoiexternal.toml.tmpl` as `git-repo` externals — chezmoi clones them and
  keeps them updated. macOS gets gitstatus via Homebrew. *Cloning only installs
  the managers:* zinit auto-installs its plugins on first interactive shell; for
  tmux run `prefix + I` once.
- **Package installs.** `run_once_after_20-install-packages.sh.tmpl` installs
  packages per-OS (Homebrew / apt). It re-runs only if its rendered content
  changes.

## Tool details

### Git

- Aliases: `g s` (status), `g l` (pretty graph log), `g ap` (add -p), `g co`
  (checkout), `g br` (branch), plus `lg`, `ll`, `lm`, `su`, `reorder`, `contrib`.
- Identity (name/email/signingkey) is templated and prompted once on
  `chezmoi init` (press Enter to accept the defaults).
- **GPG commit signing** is enabled automatically when you provide a signingkey at
  init (`[commit] gpgsign = true`); leave the signingkey blank to keep it off.
- `pull.rebase = true`, `rebase.autoStash = true`.
- Editor set to `nvim`.

### Zsh

`.zshrc` sources every file in `~/.zsh/` in lexicographic order (`00-os`,
`01-brew`, `02-zinit`, `alias`, `env`, `function`, `promptrc`, …), making it easy
to add or reorder config.

**Plugins** (via [zinit](https://github.com/zdharma-continuum/zinit)):
- `zsh-syntax-highlighting` — command highlighting
- `zsh-autosuggestions` — fish-like suggestions
- `zsh-jump-target` — quick directory jumping
- `dircolors-solarized` — solarized color scheme for `ls`

The prompt is a custom theme powered by
[gitstatus](https://github.com/romkatv/gitstatus) for fast git status.

**Notable aliases**: `vim` → `nvim`, `cd` → `cdls` (auto-`ls` after cd), `_` →
`sudo`, `extract` → `aunpack`.

**Customization**: Add personal/private overrides to `~/.custom` (sourced at the
end of `.zshrc`). chezmoi creates it once from a template (`create_dot_custom`)
and never overwrites it.

See [`home/dot_zsh/README.md`](home/dot_zsh/README.md) for the full breakdown
(per-file structure, functions, and the complete alias reference).

### tmux

- 256-color terminal with a blue status bar
- 1-based window/pane indexing
- `prefix + \` / `prefix + -` for horizontal/vertical splits (preserves the
  working directory)
- Session auto-save every 5 minutes and auto-restore on start

**Plugins** (via [TPM](https://github.com/tmux-plugins/tpm)):
- `tmux-sensible` — sensible defaults
- `tmux-prefix-highlight` — visual prefix indicator
- `tmux-resurrect` — session save/restore
- `tmux-continuum` — automatic session saving

TPM itself is cloned by chezmoi (external); run `prefix + I` once to install the
plugins.

### Neovim

Lua-based configuration on [LazyVim](https://www.lazyvim.org/) using
[lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management. Plugin
versions are intentionally **unpinned** (`lazy-lock.json` is not managed).

**Plugins**:
- `neo-tree` — file explorer
- `solarized` — color scheme
- `blink` — completion
- `better-whitespace` — trailing whitespace highlighting
- `snacks` — UI utilities / picker

See [`home/dot_config/nvim/README.md`](home/dot_config/nvim/README.md) for the
full breakdown (options, keymaps, per-plugin notes, autocommands).

### Claude Code

Only curated config is managed — `CLAUDE.md`, `settings.json`,
`statusline-command.sh`, `skills/`, and plugin config
(`plugins/known_marketplaces.json`, `plugins/blocklist.json`). Everything else in
`~/.claude` (sessions, projects, history, caches, `settings.local.json`,
credentials) is left untouched.

> **Caveat:** the plugin JSONs include app-maintained fields (`lastUpdated`,
> `installLocation`, `fetchedAt`) that Claude Code rewrites, so `chezmoi status`
> may show them as drifted and `apply` reverts those fields. `installLocation` is
> also macOS-specific. If the churn is annoying, drop them from management.

## Docker testing (Debian)

```bash
docker compose up -d --build
docker compose exec debian bash
# inside the container:
chezmoi init --source=/workspace --apply
```

## License

MIT — see [LICENSE](LICENSE).
