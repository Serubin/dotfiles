" ========================================
" Vim plugin configuration
" ========================================
"
" This file contains the list of plugin installed using vundle plugin manager.
" Once you've updated the list of plugin, you can run vundle update by issuing
" the command :BundleInstall from within vim or directly invoking it from the
" command line with the following syntax:
" vim --noplugin -u vim/vundles.vim -N "+set hidden" "+syntax on" +BundleClean! +BundleInstall +qall
" Filetype off is required by vundle
filetype off

set rtp+=$HOME/.vim/bundle/vundle/
call vundle#begin("$HOME/.vim/bundle")

" let Vundle manage Vundle (required)
Bundle "gmarik/vundle"

" Keeping vim rather simple

" Generic
Bundle "itchyny/lightline.vim"
Bundle "tpope/vim-fugitive"

" Completion & snippets
Plugin 'Valloric/YouCompleteMe'
Plugin 'rdnetto/YCM-Generator'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'

Bundle "scrooloose/syntastic"

" Load LaTeX if installed
if filereadable(expand("~/.vim/latex.vim"))
    " Vimtex plugin
    Plugin 'lervag/vimtex'
    source ~/.vim/latex.vim
endif

if filereadable(expand("~/.vim/vhdl.vim"))
    " Vimtex plugin
    Plugin 'JPR75/VIP'
    Plugin 'hdl_plugin'
    Plugin 'salinasv/vim-vhdl'
    source ~/.vim/vhdl.vim
endif

" Web
Bundle "pangloss/vim-javascript"
Plugin 'Valloric/MatchTagAlways'
Plugin 'othree/html5.vim'

" Tags
Plugin 'ctrlpvim/ctrlp.vim'

call vundle#end()

"Filetype plugin indent on is required by vundle
filetype plugin indent on
