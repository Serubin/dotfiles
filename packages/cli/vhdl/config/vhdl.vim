let g:UltiSnipsSnippetDir="~/.config/nvim/UltiSnips/"
let g:vhdl_indent_genportmap = 0 " Keeps Vim from indenting port maps too much
let g:HDL_Clock_Period = 10
let g:HDL_Author = system("git config --global user.name")
nnoremap <leader>C <Plug>SpecialVHDLPasteComponent
nnoremap <leader>I <Plug>SpecialVHDLPasteInstance
nnoremap <leader>E <Plug>SpecialVHDLPasteEntity
