# Neovim Configuration

Lua-based Neovim config built on [LazyVim](https://www.lazyvim.org/) with the [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager.

## Structure

```
nvim/
├── nvim/
│   ├── init.lua                 # Entry point — loads lazy_init
│   └── lua/
│       ├── lazy_init.lua        # Bootstraps lazy.nvim + LazyVim, sets leader keys
│       ├── config/
│       │   ├── options.lua      # Editor options (no autoformat, scrolloff, etc.)
│       │   └── keymaps.lua      # Custom key mappings
│       └── plugins/
│           ├── autocmds.lua     # Git commit template formatting
│           ├── blink.lua        # Completion (super-tab preset, disabled in markdown/comments)
│           ├── betterwhitespace.lua  # Trailing whitespace highlighting + auto-strip
│           ├── disabled.lua     # Explicitly disabled LazyVim defaults
│           ├── neo-tree.lua     # File explorer
│           ├── solarized.lua    # Solarized colorscheme
│           └── snackes.lua      # Snacks picker (shows hidden + ignored files)
└── setup/
    ├── darwin                   # brew install nvim
    ├── debian                   # brew or build from source; sets vi/vim/editor alternatives
    └── build-neovim             # Builds latest Neovim from source on Debian
```

Stowed into `~/.config/` so `nvim/nvim/` maps to `~/.config/nvim/`.

## Options

| Option | Value | Notes |
|--------|-------|-------|
| `autoformat` | `false` | No format-on-save |
| `relativenumber` | `false` | Absolute line numbers |
| `scrolloff` | `8` | Keep 8 lines visible above/below cursor |
| `fixendofline` | `true` | Ensure files end with a newline |

## Keymaps

| Key | Action |
|-----|--------|
| `<Space>` | Leader |
| `\` | Local leader |
| `<Tab>` | Previous buffer |
| `<S-Tab>` | Next buffer |
| `<Leader><Tab>` | Open Neo-tree file explorer |

## Plugins

### Active

| Plugin | Purpose | Notes |
|--------|---------|-------|
| [LazyVim](https://www.lazyvim.org/) | Base distribution | Provides sensible defaults, extras, and plugin specs |
| [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) | File explorer | Loaded eagerly; mapped to `<Leader><Tab>` |
| [solarized](https://github.com/altercation/vim-colors-solarized) | Colorscheme | Set as the default colorscheme |
| [blink.cmp](https://github.com/saghen/blink.cmp) | Completion | Super-tab keymap preset; disabled in gitcommit, markdown, comments, and prompt buffers |
| [snacks.nvim](https://github.com/folke/snacks.nvim) | UI utilities / picker | Picker configured to show hidden and gitignored files |
| [vim-better-whitespace](https://github.com/ntpeters/vim-better-whitespace) | Whitespace highlighting | Red highlight on trailing whitespace; auto-strips on save; disabled in dashboard/picker/lazy buffers |

### Autocommands

- **Git commit template**: When a gitcommit buffer's first line starts with `##`, two blank lines are inserted at the top and the cursor is placed at line 1. This allows typing a commit message above the template.

### Disabled

These LazyVim defaults are explicitly turned off:

- `mini.ai` (coding)
- `tokyonight.nvim`, `catppuccin/nvim` (colorschemes — replaced by solarized)
- `grug-far.nvim` (search/replace)

### Performance

Some built-in runtime plugins are disabled for faster startup: `gzip`, `tarPlugin`, `tohtml`, `tutor`, `zipPlugin`.

Plugin update checks run once per day (silently).

## Installation

Handled automatically by the dotfiles install script. On Debian without Homebrew, Neovim is built from source using the latest tagged release. On macOS or Debian with Homebrew, it's installed via `brew`. On Debian, `vi`, `vim`, and `editor` alternatives are pointed to `nvim`.
