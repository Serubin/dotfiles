syntax on

set nocompatible
set number                      "Line numbers are good
highlight LineNr ctermfg=grey   "Colored line numbers are better"
set title                       "Titles are cool
set hidden                      "Hide buffer instead of closing it - stop buffering of empty files
set pastetoggle=<F2>            "Paste without being smart
set backspace=indent,eol,start  "Allow backspace in insert mode
set history=1000                "Store lots of :cmdline history
set showcmd                     "Show incomplete cmds down the bottom
set visualbell                  "No sounds
set noerrorbells                "Removes error bells
set autoread                    "Reload files changed outside vim
set autoindent                  "Auto indentation
set smartindent                 "Smart indentation
set smartcase                   "Smart casing
set smarttab                    "Smart tab
set hlsearch                    "Highlights search results
set incsearch                   "Includes partial searches
set showmatch                   "Shows matching braces
set ignorecase                  "Ignores case in searches
set shiftround                  "Move word to word with shift navigation
set history=1000                "Command history
set undolevels=1000             "Undo history
set udf                         "Persistant undo across sessions

" Tex stuff
augroup latex
    autocmd!
    autocmd FileType tex setlocal spell spelllang=en_us
    autocmd BufWinEnter *.tex :VimtexCompile 
augroup END
let g:tex_flavor='latex'
" Testing Tex stuff
if !exists('g:ycm_semantic_triggers')
  let g:ycm_semantic_triggers = {}
endif
let g:ycm_semantic_triggers.tex = [
      \ 're!\\[A-Za-z]*(ref|cite)[A-Za-z]*([^]]*])?{([^}]*, ?)*'
        \ ]

"Tabs to spaces
set tabstop=4 shiftwidth=4 expandtab
" netrw 
let g:netrw_liststyle=3         "List styles for file explorer
let g:netrw_altv=1
let g:netrw_preview=1
let g:netrw_sort_sequence = '[\/]$,*' " sort is affecting only: directories on the top, files below
let g:netrw_list_hide= '.*\.swp$'
let asmsyntax='armasm'
let filetype_inc='armasm'

" Key mappings
let mapleader = "\<Space>"
nnoremap <leader>c :noh<cr>         " Clear search highlighting with <space>c
nnoremap <tab> :bnext<cr>           " Tab to next buffer
nnoremap <s-tab> :bprevious<cr>     " Shift-tab to previous buffer
noremap <Leader><tab> :call VexToggle(getcwd())<CR> " vex mappings
noremap <Leader>` :call VexToggle("")<CR>

" Load plugins
if filereadable(expand("~/.vim/vundle.vim"))
  source ~/.vim/vundle.vim
endif

" colors
let g:rehash256 = 1
if filereadable(expand("~/.vim/colors/molokia.vim"))
    source ~/.vim/colors/molokia.vim
    set t_ut=
endif

" vex menu
if filereadable(expand("~/.vim/vex.vim"))
    source ~/.vim/vex.vim
endif

" Undo
if has('persistent_undo')
  silent !mkdir ~/.vim/undo > /dev/null 2>&1
  set undodir=~/.vim/undo
  set undofile
endif

" lightline
set laststatus=2 " no display fix
set noshowmode

if !has('gui_running') " no color fix
    set t_Co=256
endif

let g:lightline = {
    \ 'colorscheme': 'powerline',
    \ }

" TODO add more lightline stuff

" use the previous window to

set wildignore=*.o,*.obj,*~ "stuff to ignore when tab completing
set wildignore+=*vim/backups*
set wildignore+=*sass-cache*
set wildignore+=*DS_Store*
set wildignore+=vendor/rails/**
set wildignore+=vendor/cache/**
set wildignore+=*.gem
set wildignore+=log/**
set wildignore+=tmp/**
set wildignore+=*.jpg,*.bmp,*.gif,*.png,*.jpeg,*.svg
set wildignore+=*.swp,*.pyc,*.bak,*.class,*.orig
set wildignore+=.git,.hg,.bzr,.svn

function! s:SetHighlightings()
    hi Pmenu           guifg=#66D9EF guibg=#000000
    hi PmenuSel                      guibg=#808080
    hi PmenuSbar                     guibg=#080808
    hi PmenuThumb      guifg=#66D9EF
endfunction
call s:SetHighlightings()
autocmd ColorScheme * call <SID>SetHighlightings()
