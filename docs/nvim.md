# nvim

NeoVim: A better extensive text editor

OS Support:
* OS X
* Debian
* Ubuntu
* Arch
* Fedora

## Configuration
This configuration supports a lot of advanced features to enable vim as an IDE.

Features supported:
* **Leader is configured to `<space>`**
* Will display trailing white space
  * Will also ask to remove unnecessary whitespace
* Buffers
  * `<leader>q` - Close buffer without destroying pane
  * `<leader>w` - Close pane without destroying buffer

* Lightline is enabled
  * Contents from left to right
    * Mode: Insert/Normal
    * Branch / Fugitive
    * Filename
    * Content Added (Denoted with `+`)
    * --- BREAK ---
    * File format (Unix/DOS/etc)
    * Encoding
    * File type
    * Percent - distance through file
    * Line info - Line #, Column #
    * Syntax Info - OK or #W/#E
  * Upper lightline
    * Open buffers
* Nerdtree file browser
  * `<leader>tab` to open
  * Standard Nerdtree use applies, will ignore swap and cache files
* UtilSnips - Jump to letter
  * `f` - Jump forward
  * `<shift>f` - Jump back
* Buffers
  * `tab` - Next buffer
  * `<shift>tab` - Previous buffer
* Syntax & Linting with ALE
  * This will load automatically on open, save, and insert-exit
  * `<space>d` - Jump-to-definition is supported when a LSP linter is present
  * Errors/Warnings are shown at the bottom left of lightline
* Fzf + Ag - Fuzzy Search
  * <C-p> Opens fuzzy file search
  * <S-p> Opens fuzzy content search
  * `<leader>p` for fuzzy buffer search

## Extras
### Custom Configurations
Custom configurations can be placed in `~/.config/nvim/custom.vim`. This file is read into the `init.vim` configuration but is not saved in the dotfiles repo.

