augroup vhdl
	autocmd!
	autocmd FileType vhdl :call VHDL_init()
augroup END
let g:UltiSnipsSnippetDir="~/.vim/UltiSnips/"
nnoremap <leader>C <Plug>SpecialVHDLPasteComponent
nnoremap <leader>I <Plug>SpecialVHDLPasteInstance
nnoremap <leader>E <Plug>SpecialVHDLPasteEntity
