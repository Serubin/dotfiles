" Useful to move around in long blocks of text
map j gj
map k gk

augroup latex
    autocmd!
    autocmd FileType tex setlocal spell spelllang=en_us
    autocmd BufWinEnter *.tex :VimtexCompile 
augroup END
let g:tex_flavor='latex'
let g:vimtex_fold_enabled = '1'
let g:vimtex_fold_manual = '1'
let g:vimtex_compiler_progname = 'nvr'
" Testing Tex stuff (not really sure what it does yet)
if !exists('g:ycm_semantic_triggers')
  let g:ycm_semantic_triggers = {}
endif
let g:ycm_semantic_triggers.tex = [
      \ 're!\\[A-Za-z]*(ref|cite)[A-Za-z]*([^]]*])?{([^}]*, ?)*'
        \ ]

" TeX PDF viewer integration
let g:vimtex_view_method = 'zathura'

