# Zsh Configuration

## Performance

| Metric | Time |
|---|---|
| Shell startup — `zsh -i`, work-devbox | ~150ms |
| Shell startup — `zsh -li` (login, e.g. ssh), work-devbox | ~155ms |
| Prompt render (in git repo) | ~2ms |

Startup is dominated by eager zinit plugin loading; prompt render is mostly the
gitstatus query. Re-measure anytime with `scripts/bench-zsh.sh`, and note which shell
*shape* you are measuring — a tmux pane is `zsh -i` (`default-command` is
`/usr/bin/env zsh`, so panes are **non-login**), while ssh gives you `zsh -li`.

Of that ~150ms, roughly 20ms is this repo and the rest is the machine's system config.
On work-devbox the base image was responsible for ~874ms of a ~1018ms pane until
`~/.local/bin/apply-etc-zsh-perf.sh` (run at startup by `~/personalize`) started caching
its eager `goenv`/`pyenv`/`nvm` initialization — see that script's header for what it
does and what it trades away.

## Structure

Managed by chezmoi (deployed to `~/.zsh/`). `.zshrc` sources all files in `~/.zsh/`
(excluding `.zwc` compiled files) in lexicographic order, but only for interactive shells
(`.zshrc` starts with `[[ $- != *i* ]] && return`). Files prefixed with numbers (e.g.,
`00-os`) load first to establish dependencies for later files.

`~/.zprofile` (also chezmoi-managed, from `dot_zprofile.tmpl`) runs *before* `~/.zshrc`, for
every login shell whether interactive or not — that's where Homebrew and GNU coreutils get
prepended onto `PATH`, since anything in `~/.zsh/*` would be invisible to non-interactive
login shells (GUI apps resolving `PATH`, editor shell-integration probes, `ssh host cmd`).

| File | Purpose |
|---|---|
| `00-os` | Exports `$DISTRO` (resolved by a chezmoi template at apply time — no runtime OS detection) |
| `02-zinit` | Initializes zinit and loads plugins |
| `alias` | Shell aliases, named directories, and keybindings |
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

#### `claude`

```zsh
claude [--work|--personal] [claude-args...]
```

Wrapper around the Claude Code CLI that picks which login to use. Claude Code keys its
whole identity — auth, `.claude.json`, projects, history — off `CLAUDE_CONFIG_DIR`, so
`--work` maps to `~/.claude-work` and `--personal` to `~/.claude-personal`. Both dirs
symlink their session state into `~/.claude`, so conversations, memory and history are
shared and only the account differs. The flag is
consumed by the wrapper; every other argument reaches the real CLI unchanged, and a flag
after a literal `--` is treated as data. Without one, the machine default comes from
`CLAUDE_CONFIG_DIR` (exported by `zz-env` from the chezmoi `environment`).

It also appends `--dangerously-skip-permissions`, except when you already passed
`--dangerously-skip-permissions` or `--permission-mode`, or when the invocation is a
subcommand (`claude mcp list`, `claude update`, …), which rejects the flag. Subcommands
are inferred — a single bare first word — rather than listed, since the list grows with
each release. The cost is that a one-word prompt (`claude refactor`) reads as a subcommand
and starts in the settings' default mode instead.

Being a function rather than an alias means it applies to interactive shells only, and
`command claude` always reaches the real binary.

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

#### `prompt_pwd`

Sets `REPLY` to the current directory as the prompt and terminal title show it: `$HOME`
collapsed to `~`, everything else literal.

Deliberately **not** `%~`, which would substitute [named directories](#named-directories)
— `~/.dotfiles` would render as `~dotfiles`. Those names exist for `cd` and completion,
not to rename locations on screen. `%d` doesn't fit either, since it wouldn't collapse
`$HOME`, so the path is built here. Two details worth preserving if you touch it: the
`$HOME/*` test is anchored on the `/` boundary (`${PWD/#$HOME/~}` would turn
`/home/coder2/x` into `~2/x`), and `%` is doubled so `print -P` doesn't eat it. It sets
`REPLY` rather than printing because a command substitution here would fork on every
prompt.

#### `pre_cmd`

Builds the pre-prompt line: optionally shows `user@host` for SSH sessions or root, then the current path (via `prompt_pwd`) in cyan, followed by git status. Also sets `Title` for the terminal window.

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
| `cm` | `chezmoi` |
| `grep` | `grep --color=auto` |
| `v` | `vim` |
| `rr` | `rm -r` |
| `vim` | `nvim` |
| `vi` | `vim` (→ `nvim`) |
| `cd` | `cdls` |
| `py` | `python` |
| `extract` | `aunpack` |
| `ipdns` | Public IP via OpenDNS |
| `ipl` | Local IP addresses |

## Named directories

Defined with `hash -d` in the `alias` file, to reach the checkouts below without typing
their full paths. Preferred over `cdfoo`-style aliases because the name is a path
*prefix*, not a fixed destination — `cd ~athena/vuln-eval` works, and `~ath<TAB>`
completes, neither of which an alias can do.

**They do not change how the prompt renders.** zsh's `%~` would substitute them
(`~/.dotfiles` becoming `~dotfiles`), which is not the point of having them — the prompt
builds its path with `prompt_pwd` instead, so it always shows the real location. See
[Prompt](#prompt-promptrc-promptprompt-theme-promptprompt-git) below.

`hash -d` is per-shell state, so shells started before a `chezmoi apply` need an
`exec zsh` before the names exist.

| Name | Path | Gate |
|---|---|---|
| `~dotfiles` | `~/.dotfiles` (the chezmoi source dir) | all machines |
| `~services` | `~/lwcode/services/vulnerability` | `.environment == "work"` |
| `~athena` | `~/lwcode/athena` | `.environment == "work"` |
| `~athena-eval` | `~/lwcode/athena/vuln-eval` | `.environment == "work"` |
| `~athena-redis` | `~/lwcode/athena/athena-redis-db` | `.environment == "work"` |
| `~helm3` | `~/lwcode/helm3-platform` | `.environment == "work"` |

> Note: `alias -r` is *not* used anywhere here. When **defining** an alias, `-r` is a
> no-op — regular is already the default, and `-g` / `-s` are what select the other
> namespaces. `-r` only does work when **listing** (`alias -r` prints just the regular
> aliases, skipping global and suffix ones) or with `-m` pattern matching.

## Plugins (zinit)

- **zsh-syntax-highlighting** — real-time command highlighting
- **zsh-jump-target** — quick cursor jumping (`^F`)
- **dircolors-solarized** — solarized color scheme for `ls` (auto-selects `gdircolors` on macOS, `dircolors` on Linux)

Inline suggestions come from **[deja](https://github.com/Giammarco-Ferranti/deja)**
— predictive ghost-text autosuggestions replacing `zsh-autosuggestions`. It's a
standalone Go binary + daemon (installed by `run_once_before_20-install-packages`:
Homebrew on macOS; on Debian/Ubuntu the `serubin/formula/deja` canary formula when brew
is available, else upstream's prebuilt release into `~/.local/bin` — both
checksum-verified prebuilt binaries, and both spelled `deja`), `eval`'d in `02-zinit`,
so it's not a zinit-managed plugin.
Right/End accept the full suggestion, Ctrl+Right accepts a word; its Tab-picker and
`^X` toggle are disabled (via empty `DEJA_CYCLE_KEY`/`DEJA_TOGGLE_KEY`) to preserve
completion and `^X^E`.
