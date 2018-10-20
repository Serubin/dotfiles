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

set rtp+=$HOME/.config/nvim/bundle/vundle/
call vundle#begin("$HOME/.config/nvim/bundle")

" let Vundle manage Vundle (required)
Plugin 'VundleVim/Vundle.vim'

" Keeping vim rather simple (Except HTML)

" Generic
Bundle "itchyny/lightline.vim"
Bundle "tpope/vim-fugitive"
Bundle "tpope/vim-abolish"
Plugin 'unblevable/quick-scope'
Plugin 'salsifis/vim-transpose'

" Completion & snippets
Plugin 'Valloric/YouCompleteMe'
Plugin 'rdnetto/YCM-Generator'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'

" Syntax
Plugin 'alisdair/vim-armasm'
Plugin 'fatih/vim-go'
Bundle 'nfnty/vim-nftables'

" Whitespace
Plugin 'ntpeters/vim-better-whitespace'

" Colorscheme
Plugin 'altercation/vim-colors-solarized'

" Linting
Bundle 'scrooloose/syntastic'

" File exploring
Bundle 'scrooloose/nerdtree'
Bundle 'jistr/vim-nerdtree-tabs'

" Writing style
Bundle 'reedes/vim-wordy'
Bundle 'dbmrq/vim-ditto'


if filereadable(expand("~/.config/nvim/webdev.vim"))
    let g:syntastic_jslint_checkers=['jslint']

    " JS Base
    Bundle "pangloss/vim-javascript"

    " Tag matching for XML
    Plugin 'Valloric/MatchTagAlways'

    " Html/css
    Plugin 'othree/html5.vim'
    Plugin 'hail2u/vim-css3-syntax'
    Plugin 'cakebaker/scss-syntax.vim'

    " Various libraries
    Plugin 'posva/vim-vue'
    Plugin 'leafgarland/typescript-vim'
    Plugin 'mxw/vim-jsx'

endif

" Load LaTeX if installed
if filereadable(expand("~/.config/nvim/ftplugin/tex.vim"))
    " Vimtex plugin
    Plugin 'lervag/vimtex'
endif

if filereadable(expand("~/.config/nvim/ftplugin/vhdl.vim"))
    " Vimtex plugin
    Plugin 'JPR75/VIP' " Copy/paste entity/component/instance
endif

" Tags
Plugin 'ctrlpvim/ctrlp.vim'

call vundle#end()

"Filetype plugin indent on is required by vundle
filetype plugin indent on
