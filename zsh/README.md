# Zsh Configuration

## Performance

| Metric | Time |
|---|---|
| Shell startup | ~60ms |
| Prompt render (in git repo) | ~0.5ms |

## Structure

The `.zshrc` sources all files in `~/.zsh/` (excluding `.zwc` compiled files) in lexicographic order. Files prefixed with numbers (e.g., `01-os`) load first to establish dependencies for later files.

| File | Purpose |
|---|---|
| `01-os` | Detects the OS/distro and exports `$DISTRO` |
| `02-zinit` | Initializes zinit and loads plugins |
| `alias` | Shell aliases and keybindings |
| `env` | Completion setup, shell options, key bindings, and environment variables |
| `function` | General-purpose helper functions |
| `promptrc` | Prompt precmd hooks and PS1 setup |
| `prompt/prompt-git` | Git status integration for the prompt |
| `prompt/prompt-theme` | Prompt theme (Pure-inspired) with color definitions |

## Functions

### General Helpers (`function`)

#### `mk`

```zsh
mk <dir> [...]
```

Create one or more directories and `cd` into the result.

#### `cdls`

```zsh
cdls [dir]
```

Change directory and automatically run `ls`. Aliased to `cd` in the alias file so every directory change shows its contents.

#### `_cache_completion`

```zsh
_cache_completion <cmd>
```

Cache a CLI tool's zsh completion to `~/.zsh/cache/<cmd>.zsh`. The cache is regenerated automatically when the tool's binary changes (by comparing modification times).

#### `lazy_load_nvm`

```zsh
lazy_load_nvm [--auto-use]
```

Lazy-load nvm so it doesn't slow down shell startup. Stubs `nvm`, `node`, `npm`, and `npx` — the real nvm is sourced on first use. Pass `--auto-use` to also auto-switch node versions when entering a directory with a `.nvmrc` file. Intended to be called from `~/.custom`:

```zsh
export NVM_DIR="$HOME/.nvm"
lazy_load_nvm --auto-use
```

### Environment (`env`)

#### `compaudit`

Overridden to always return `0`, suppressing false-positive insecure-directory warnings from `compinit`.

#### `_set-list-colors`

Deferred (via `sched 0`) setup that applies `$LS_COLORS` to completion listings. Self-unloads after first invocation.

### Prompt (`promptrc`, `prompt/prompt-theme`, `prompt/prompt-git`)

#### `prompt_precmd`

Precmd hook that trims the displayed directory depth, calls `pre_cmd` to render the informational line, and sets the terminal title.

#### `install_prompt_precmd`

Idempotently registers `prompt_precmd` into the `precmd_functions` array.

#### `pre_cmd`

Builds the pre-prompt line: optionally shows `user@host` for SSH sessions or root, then the current path in cyan, followed by git status.

#### `git_stat`

Returns a colorized string with the current git branch and dirty/clean indicator. Used by `pre_cmd` to embed git info in the prompt.

#### `__git_ps1`

Core git-prompt function (from the official git-prompt.sh). Accepts 0-3 arguments and produces a formatted string with the branch name, rebase/merge state, dirty/staged/stash/untracked indicators, and upstream divergence.

#### `__git_ps1_show_upstream`

Computes ahead/behind counts relative to the upstream branch (git or SVN).

#### `__git_ps1_colorize_gitstring`

Applies color codes to the components of the git prompt string (branch, dirty, staged, stash, untracked).

#### `__git_eread`

Reads the contents of a file into a variable. Used internally by `__git_ps1` to inspect git state files.

## Aliases (quick reference)

| Alias | Expansion |
|---|---|
| `..` / `...` / `....` | `cd ..` / `cd ../..` / `cd ../../..` |
| `la` | `ls -A` |
| `ll` | `ls -lhAr` |
| `_` | `sudo` |
| `g` | `git` |
| `v` | `vim` |
| `rr` | `rm -r` |
| `vim` | `nvim` |
| `vi` | `vim` (→ `nvim`) |
| `cd` | `cdls` |
| `py` | `python` |
| `extract` | `aunpack` |
| `ipdns` | Public IP via OpenDNS |
| `ipl` | Local IP addresses |

## Plugins (zinit)

- **zsh-syntax-highlighting** — real-time command highlighting
- **zsh-autosuggestions** — fish-style autosuggestions
- **zsh-jump-target** — quick cursor jumping (`^F`)

- **dircolors-solarized** — solarized color scheme for `ls` (auto-selects `gdircolors` on macOS, `dircolors` on Linux)
