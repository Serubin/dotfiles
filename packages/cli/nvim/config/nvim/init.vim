set nocompatible
set number                      "Line numbers are good
highlight LineNr ctermfg=grey   "Colored line numbers are better
set cursorline                  "highlight current line
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
set list                        "Show trailing whitespace with a <
set listchars=tab:>.,trail:<    "Set trailing listchars
set incsearch                   "Includes partial searches
set showmatch                   "Shows matching braces
set ignorecase                  "Ignores case in searches
set shiftround                  "Move word to word with shift navigation
set undolevels=1000             "Undo history
set udf                         "Persistant undo across sessions
set scrolloff=8                 "Makes cursor stay 8 lines away from the top or bottom
set mouse=""                    "Turns off mouse interaction
set inccommand=nosplit          "In place substitution preview
set wildmode=longest:full,full
"Tabs to spaces
set tabstop=4 shiftwidth=4 expandtab

" Set yaml to 2 spaces
au FileType yaml setl sw=2 sts=2 et

" Go
au FileType go set noexpandtab
au FileType go set shiftwidth=4
au FileType go set softtabstop=4
au FileType go set tabstop=4
autocmd BufNewFile,BufRead *.go set listchars& " Unset listchars
autocmd BufNewFile,BufRead *.go set list! " Unset listchars

let $NVIM_TUI_ENABLE_CURSOR_SHAPE=0

" nerdtree
let NERDTreeShowHidden=1
let NERDTreeSortOrder=['[\/]$', '*']
let NERDTreeIgnore=['.*\.swp$', '.*\.swo$', '.*\.pyc$']

" Syntax Checking
let b:ale_linters = {'javascript': ['eslint']}
let g:ale_lint_on_insert_leave = 1
nnoremap <leader>d :ALEGoToDefinition<cr>
" Remove underlines in favor of gutter inidcations
let g:ale_set_highlights = 1
highlight ALEError ctermbg=234
highlight ALEWarning ctermbg=234

augroup blahblahbalh
    autocmd!
    autocmd FileType tex vnoremap <Leader>b s\textbf{<ESC>pa}<ESC>
    autocmd FileType tex vnoremap <Leader>t s\texttt{<ESC>pa}<ESC>
augroup END

augroup skip_error_buffer
    autocmd!
    autocmd FileType qf setlocal nobuflisted
augroup END

function! ToggleErrors()
    let old_last_winnr = winnr('$')
    lclose
    if old_last_winnr == winnr('$')
        " Nothing was closed, open syntastic error location panel
        Errors
    endif
endfunction

let asmsyntax='armasm'
let filetype_inc='armasm'

" Key mappings
let mapleader = "\<Space>"
let maplocalleader = "\\"
nnoremap <leader>c :noh<cr>
nnoremap <tab> :bnext<cr>           " Tab to next buffer
nnoremap <s-tab> :bprevious<cr>     " Shift-tab to previous buffer
noremap <Leader><tab> :NERDTreeTabsToggle<CR>
noremap <Leader>` :call VexToggle("")<CR>
noremap <Leader>i :exe "normal i".nr2char(getchar())<CR>
nnoremap <silent> <C-e> :<C-u>call ToggleErrors()<CR>
nnoremap <silent> <Leader>q :bp\|bd #<CR>
noremap <Leader>w :hide<CR>
nnoremap <Leader>s :%s/\<<C-r><C-w>\>/

map j gj
map k gk

" Trigger a highlight in the appropriate direction when pressing these keys:
let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']

let g:better_whitespace_enabled=1
let g:strip_whitespace_on_save=1

augroup spell_check
    autocmd!
    autocmd FileType no ft setlocal spell spelllang-en_us
augroup END

if filereadable(expand("~/.config/nvim/python.vim"))
    source ~/.config/nvim/python.vim
endif

" Load plugins
if filereadable(expand("~/.config/nvim/vundle.vim"))
  source ~/.config/nvim/vundle.vim
endif

if filereadable(expand("~/.config/nvim/pass.vim"))
  source ~/.config/nvim/pass.vim
endif

" WebDev Stuff
if filereadable(expand("~/.config/nvim/webdev.vim"))
    let g:vue_disable_pre_processors=1
    autocmd FileType vue syntax sync fromstart
    autocmd BufRead,BufNewFile *.vue setlocal filetype=vue.html.javascript.css.less.pug
    autocmd BufRead,BufNewFile *.js,*.ts,*.tsx,*.jsx set filetype=typescript.tsx
    autocmd FileType *.tsx,*.jsx setlocal shiftwidth=2 softtabstop=2 expandtab
endif


" better key bindings for UltiSnipsExpandTrigger
let g:UltiSnipsExpandTrigger = "<C-j>"
let g:UltiSnipsJumpForwardTrigger = "<C-j>"
let g:UltiSnipsJumpBackwardTrigger = "<C-k>"

" colors
if isdirectory(expand("~/.config/nvim/bundle/vim-colors-solarized/"))
    let g:solarized_termcolors=256
    syntax enable
    set background=dark
    colorscheme solarized
endif

highlight ColorColumn ctermbg=235 guibg=#2c2d27
let &colorcolumn=join(range(81,999),",")

" Undo
if has('persistent_undo')
  silent !mkdir ~/.config/nvim/undo > /dev/null 2>&1
  set undodir=~/.config/nvim/undo
  set undofile
endif

" lightline
set laststatus=2 " no display fix
set noshowmode

let g:lightline = {
      \ 'colorscheme': 'powerline',
      \ 'mode_map': { 'c': 'NORMAL' },
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ], [ 'fugitive', 'filename' ] ],
      \   'right': [ [ 'lineinfo', 'syntasticstatus' ],
      \              [ 'percent' ],
      \              [ 'fileformat', 'fileencoding', 'filetype' ] ]
      \ },
      \ 'tabline': {'left': [['buffers']]},
      \ 'component_function': {
      \   'modified': 'LightlineModified',
      \   'readonly': 'LightlineReadonly',
      \   'fugitive': 'LightlineFugitive',
      \   'filename': 'LightlineFilename',
      \   'fileformat': 'LightlineFileformat',
      \   'filetype': 'LightlineFiletype',
      \   'fileencoding': 'LightlineFileencoding',
      \   'mode': 'LightlineMode',
      \   'syntasticstatus': 'LinterStatus',
      \ },
      \ 'component_expand': {
      \   'buffers': 'lightline#bufferline#buffers',
      \ },
      \ 'component_type': {
      \   'buffers': 'tabsel',
      \ },
      \ 'separator': { 'left': '', 'right': '' },
      \ 'subseparator': { 'left': '', 'right': '' }
      \ }

let g:lightline#bufferline#show_number = 1
let g:lightline#bufferline#filename_modifier = ':t'
set showtabline=2

function! LightlineModified()
  return &ft =~ 'help\|vimfiler\|gundo\|NERD' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! LightlineReadonly()
  return &ft !~? 'help\|vimfiler\|gundo' && &readonly ? '' : ''
endfunction

function! LightlineFilename()
  return ('' != LightlineReadonly() ? LightlineReadonly() . ' ' : '') .
        \ (&ft == 'vimfiler' ? vimfiler#get_status_string() :
        \  &ft == 'unite' ? unite#get_status_string() :
        \  &ft == 'vimshell' ? vimshell#get_status_string() :
        \ '' != expand('%:t') ? expand('%:t') : '[No Name]') .
        \ ('' != LightlineModified() ? ' ' . LightlineModified() : '')
endfunction

function! LightlineFugitive()
  if &ft !~? 'vimfiler\|gundo\|NERD' && exists("*fugitive#head")
    let branch = fugitive#head()
    return branch !=# '' ? ''.branch : ''
  endif
  return ''
endfunction

function! LightlineFileformat()
  return winwidth(0) > 70 ? &fileformat : ''
endfunction

function! LightlineFiletype()
  return winwidth(0) > 70 ? (&filetype !=# '' ? &filetype : 'no ft') : ''
endfunction

function! LightlineFileencoding()
  return winwidth(0) > 70 ? (&fenc !=# '' ? &fenc : &enc) : ''
endfunction

function! LightlineMode()
  return winwidth(0) > 60 ? lightline#mode() : ''
endfunction

function! LinterStatus() abort
    let l:counts = ale#statusline#Count(bufnr(''))

    let l:all_errors = l:counts.error + l:counts.style_error
    let l:all_non_errors = l:counts.total - l:all_errors

    return l:counts.total == 0 ? 'OK' : printf(
    \   '%dW %dE',
    \   all_non_errors,
    \   all_errors
    \)
  endfunction

if !has('gui_running') " no color fix
    set t_Co=256

    " Odd `esc` lag fix
    set ttimeoutlen=10
    set nottimeout
    augroup FastEscape
        autocmd!
        au InsertEnter * set timeoutlen=0
        au InsertLeave * set timeoutlen=1000
    augroup END
endif


" use the previous window to

set wildignore=*.o,*.obj,*~ "stuff to ignore when tab completing
set wildignore=*.pdf
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
set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
set wildignore+=*\\tmp\\*,*.swp,*.zip,*.exe  " Windows


set tags=tags,.git/tags
"let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'
"let g:ctrlp_custom_ignore = {
 " \ 'dir':  '\v[\/]\.(git|hg|svn)$',
 " \ 'file': '\v\.(exe|so|dll)$',
 " \ 'link': 'some_bad_symbolic_links',
 " \ }

augroup makefile
     autocmd!
     autocmd FileType make setlocal noexpandtab
augroup END

function! s:SetHighlightings()
    hi Pmenu           guifg=#66D9EF guibg=#000000
    hi PmenuSel                      guibg=#808080
    hi PmenuSbar                     guibg=#080808
    hi PmenuThumb      guifg=#66D9EF
endfunction

call s:SetHighlightings()
autocmd ColorScheme * call <SID>SetHighlightings()

" Spell check
autocmd BufRead,BufNewFile *.md setlocal spell spelllang=en_us

" Load Custom
if filereadable(expand("~/.config/nvim/custom.vim"))
  source ~/.config/nvim/custom.vim
endif

