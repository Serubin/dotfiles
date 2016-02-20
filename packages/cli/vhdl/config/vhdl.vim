augroup vhdl
	autocmd!
	autocmd FileType vhdl setlocal omnifunc=syntaxcomplete#Complete
augroup END
let g:UltiSnipsSnippetDir="~/.vim/UltiSnips/"
nnoremap <leader>C <Plug>SpecialVHDLPasteComponent
nnoremap <leader>I <Plug>SpecialVHDLPasteInstance
nnoremap <leader>E <Plug>SpecialVHDLPasteEntity
