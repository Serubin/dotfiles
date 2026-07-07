# Zsh Configuration

## Performance

| Metric | Time |
|---|---|
| Shell startup | ~80ms |
| Prompt render (in git repo) | ~2ms |

Startup is dominated by eager zinit plugin loading; prompt render is mostly the
gitstatus query. Re-measure anytime with `scripts/bench-zsh.sh`.

## Structure

Managed by chezmoi (deployed to `~/.zsh/`). `.zshrc` sources all files in `~/.zsh/`
(excluding `.zwc` compiled files) in lexicographic order. Files prefixed with numbers
(e.g., `00-os`) load first to establish dependencies for later files.

| File | Purpose |
|---|---|
| `00-os` | Exports `$DISTRO` (resolved by a chezmoi template at apply time — no runtime OS detection) |
| `01-brew` | Adds Homebrew to `PATH` on macOS |
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

Returns a colorized string describing the current git repo via
[gitstatus](https://github.com/romkatv/gitstatus): the branch name (or a short SHA /
tag when detached), any in-progress action state (rebase/merge/cherry-pick/revert/am/
bisect), and a single dirty indicator — a red `*` — shown whenever there are staged,
unstaged, untracked, or conflicted changes (a clean tree renders with no marker). Used
by `pre_cmd` to embed git info in the prompt.

> **Dependency:** the prompt requires romkatv/gitstatus. `prompt-git` loads it and starts
> a persistent background daemon; on Linux it's cloned via `.chezmoiexternal` to
> `~/.zsh/gitstatus`, and on macOS it's provided by Homebrew.

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
