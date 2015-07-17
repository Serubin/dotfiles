syntax on

set nocompatible
set number						"Line numbers are good
highlight LineNr ctermfg=grey	"Colored line numbers are better"
set title						"Titles are cool
set hidden					 	"Hide buffer instead of closing it - stop buffering of empty files
set pastetoggle=<F2>			"Paste without being smart
set backspace=indent,eol,start  "Allow backspace in insert mode
set history=1000				"Store lots of :cmdline history
set showcmd						"Show incomplete cmds down the bottom
set visualbell					"No sounds
set noerrorbells				"Removes error bells
set autoread					"Reload files changed outside vim
set ruler						"Shows file ruler
set autoindent					"Auto indentation
set smartindent					"Smart indentation
set smartcase					"Smart casing
set smarttab					"Smart tab
set hlsearch					"Highlights search results
set incsearch					"Includes partial searches
set showmatch					"Shows matching braces
set ignorecase					"Ignores case in searches
set shiftround					"Move word to word with shift navigation
set history=1000				"Command history
set undolevels=1000				"Undo history

let g:netrw_liststyle=3 		"List styles for file explorer

" Key mappings
nnoremap <leader><space> :noh<cr>	" Clear search highlighting with ,<space>
nnoremap <tab> :bnext<cr>			" Tab to next buffer
nnoremap <s-tab> :bprevious<cr>		" Shift-tab to previous buffer

" Load plugins
if filereadable(expand("~/.vim/vundle.vim"))
  source ~/.vim/vundle.vim
endif

" colors
let g:rehash256 = 1
if filereadable(expand("~/.vim/colors/molokia.vim"))
	source ~/.vim/colors/molokia.vim
endif

" Undo
if has('persistent_undo')
  silent !mkdir ~/.vim/undo > /dev/null 2>&1
  set undodir=~/.vim/undo
  set undofile
endif

" lightline
set laststatus=2 " no display fix
set noshowmode " TODO something preventing this. fix
let g:lightline = {
    \ 'colorscheme': 'powerline',
    \ }

" TODO add more lightline stuff

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
