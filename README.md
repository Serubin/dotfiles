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

`chezmoi init` prompts once for the machine environment/class (see
[Machine targeting](#machine-targeting)) and your git name/email/signingkey
(press Enter to accept defaults), clones the plugin managers, installs packages
for your OS, and writes the managed files into `$HOME`.

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

## Machine targeting

Every machine resolves two facts at `chezmoi init`, persisted in the local config
(`~/.config/chezmoi/chezmoi.toml`) and used to gate config, scripts, and packages:

- **`environment`** — the trust boundary, **validated** to `personal` or `work`.
  The axis behind personal-only vs work-only gating.
- **`class`** — a free-form role tag, **not validated**. Defaults to a value
  derived from `environment` + OS, but you can override it with any string.

The four default classes are the cross-product of `environment` and OS:

|              | macOS            | Linux              |
|--------------|------------------|--------------------|
| **personal** | `personal-mac`   | `personal-server`  |
| **work**     | `work-mac`       | `work-devbox`      |

Custom classes (e.g. `homelab`, `work-ci`) are allowed — they just won't match the
default-class gates, so add your own gate for them.

### Setting it

`chezmoi init` prompts once (press Enter to accept the derived class default). To
answer non-interactively — scripted installs, CI, `curl | sh`:

```bash
DOTFILES_ENV=work chezmoi init --apply                          # environment only
DOTFILES_ENV=work DOTFILES_CLASS=work-ci chezmoi init --apply   # custom class
./install.sh --env work                                         # bootstrap wrapper
./install.sh --env work --class work-ci                         # env + custom class
```

`install.sh` also accepts `--env`/`--class` as `--env=work`, and a bare
`personal`/`work` positional still works as an `--env` shorthand.

To change a machine later, edit `[data]` in `~/.config/chezmoi/chezmoi.toml`
(`environment` / `class`) and `chezmoi apply`, or re-init. Both values are exported
into your shell as `$DOTFILES_ENV` / `$DOTFILES_CLASS` (via `~/.zsh/zz-env`), so
scripts and interactive config can branch on them.

> **Existing machines:** a machine initialized before this feature has no
> `environment`/`class` in its config. Run `chezmoi init` once (git identity is
> remembered; you'll only be asked the new prompts) to populate them before the
> next `chezmoi apply`.

### Feature matrix

Hand-maintained — keep in sync with the gating logic.

| Feature | personal-mac | personal-server | work-mac | work-devbox |
|---|:---:|:---:|:---:|:---:|
| Core: zsh, git, tmux, Neovim | ✅ | ✅ | ✅ | ✅ |
| Homebrew base packages | ✅ | — | ✅ | — |
| yabai + skhd (config + install) | ✅ | — | ✅ | — |
| `~/.local/bin` on PATH | ✅ | ✅ | ✅ | ✅ |
| Per-class packages (`run_once_after_21`) | — | — | opt-in | opt-in |
| `example-work-mac` script | — | — | ✅ | — |
| `example-work-devbox` script | — | — | — | ✅ |

### Adding a class-gated file or script

Drop the file in the chezmoi source (e.g. `home/dot_local/bin/executable_foo`
→ `~/.local/bin/foo`), then gate it in [`home/.chezmoiignore`](home/.chezmoiignore)
at whichever level fits — patterns match target paths and can branch on any
`[data]` value:

```gotemplate
{{ if ne .chezmoi.os "darwin" }}.config/yabai{{ end }}    # by OS  (any mac)
{{ if ne .environment "work" }}.local/bin/vpn{{ end }}    # by environment
{{ if ne .class "work-mac" }}.local/bin/foo{{ end }}      # by exact class tag
```

For per-machine *shell* config, add it to
[`home/dot_zsh/zz-env.tmpl`](home/dot_zsh/zz-env.tmpl) (which branches on `.class`)
rather than ignore-gating a sourced file: `.chezmoiignore` never removes an
already-applied file, so a reclassified machine would keep sourcing a stale one.

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
| Git | `~/.config/git/{config,ignore}`, `~/.gitconfig_local` | Aliases, templated identity, global ignore, `gh` credential helper, machine-local overrides |
| Zsh | `~/.zshrc`, `~/.zshenv`, `~/.zsh/` | Modular config, zinit plugins, custom prompt |
| tmux | `~/.tmux.conf` | 256-color, TPM plugins, session restore |
| Neovim | `~/.config/nvim/` | Lua config with lazy.nvim |
| Claude Code | `~/.claude/` (curated) | CLAUDE.md, settings.json, statusline, skills, plugin config |
| yabai + skhd | `~/.config/{yabai,skhd}` | macOS tiling WM + hotkey daemon (macs only) |

## Repository layout

```
.dotfiles/
├── .chezmoiroot                      # → home   (chezmoi source root)
├── home/
│   ├── .chezmoi.toml.tmpl            # init prompts (environment/class + git identity)
│   ├── .chezmoiignore                # runtime/secret paths chezmoi must not manage
│   ├── .chezmoiexternal.toml.tmpl    # zinit, tpm, gitstatus (cloned & auto-updated)
│   ├── .chezmoiscripts/
│   │   ├── run_once_before_10-uninstall-stow.sh
│   │   ├── run_once_before_20-install-packages.sh.tmpl      # base tools (incl. gh) BEFORE configs render
│   │   ├── run_once_after_15-migrate-git-xdg.sh            # one-time: drop legacy ~/.gitconfig
│   │   └── run_once_after_21-install-env-packages.sh.tmpl  # per-class packages
│   ├── dot_zshenv  dot_zshrc
│   ├── dot_zsh/                      # 00-os 01-brew executable_02-zinit alias env function promptrc zz-env prompt/
│   ├── dot_local/bin/               # → ~/.local/bin (on PATH); class-gated scripts
│   ├── dot_tmux.conf
│   ├── create_dot_custom             # ~/.custom (created once, never overwritten)
│   ├── create_dot_gitconfig_local    # ~/.gitconfig_local (created once; machine-local git overrides)
│   ├── dot_config/git/               # → ~/.config/git/{config.tmpl,ignore} (XDG git config)
│   ├── dot_config/nvim/
│   └── dot_claude/                   # CURATED: CLAUDE.md, settings.json, statusline, skills/, plugins/*.json
├── scripts/
│   ├── uninstall-stow.sh             # remove legacy Stow symlinks (manual)
│   └── docker-test.sh                # → `dotfiles-test` in the container: apply + login zsh
├── Dockerfile  docker-compose.yml    # Debian test harness (non-root sudo user)
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
- **Package installs.** `run_once_before_20-install-packages.sh.tmpl` installs
  base packages per-OS (Homebrew / apt); `run_once_after_21-install-env-packages`
  adds per-class packages. Each re-runs only if its rendered content changes. The
  base install is a `run_before_` hook so its tools exist before configs render —
  e.g. gh must be present for the git template's `lookPath "gh"` credential-helper
  block to render on the first apply, so a single apply converges.
- **Machine targeting.** `environment` (personal/work) and `class` are set at init
  and gate templates, `.chezmoiignore`, and the package scripts — see
  [Machine targeting](#machine-targeting).

## Tool details

### Git

- Aliases: `g s` (status), `g l` (pretty graph log), `g ap` (add -p), `g co`
  (checkout), `g br` (branch), plus `lg`, `ll`, `lm`, `su`, `reorder`, `contrib`.
- Identity (name/email/signingkey) is templated and prompted once on
  `chezmoi init`. No name or address is hardcoded in the repo, so fill them in when
  prompted (values persist afterward).
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
- `zsh-jump-target` — quick directory jumping
- `dircolors-solarized` — solarized color scheme for `ls`

Inline suggestions come from [deja](https://github.com/Giammarco-Ferranti/deja)
— predictive ghost-text autosuggestions (replaces `zsh-autosuggestions`).
It's a Homebrew binary + daemon, initialized in `02-zinit`, not a zinit plugin.

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

Spins up a Debian container as a **non-root user with passwordless sudo** (so the
`sudo` package installs are actually exercised) with the repo mounted read-only at
`/workspace`.

```bash
docker compose up -d --build
docker compose exec debian dotfiles-test   # bootstrap (prompts) + drop into login zsh
# or, without applying:
docker compose exec debian zsh
```

`dotfiles-test` runs `chezmoi init --apply` against the mounted source and drops
you into the configured login zsh; it's idempotent, so re-running is a fast
re-apply. Seed the env/class prompts non-interactively via the commented
`environment:` block in `docker-compose.yml` (or `DOTFILES_ENV=… DOTFILES_CLASS=…
docker compose exec debian dotfiles-test`).

> **Neovim caveat:** the image pre-installs Debian's `nvim` so the harness skips
> the multi-minute from-source build (`run_once_before_20`). That apt build is
> older than what a real machine gets; it's fine for testing the dotfiles config,
> but to exercise the source-build path, drop `neovim` from the `Dockerfile`.

## License

MIT — see [LICENSE](LICENSE).
