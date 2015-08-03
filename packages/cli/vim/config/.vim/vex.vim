"
" Vim Vex sidebar
" From: https://github.com/ivanbrennan/dotvim
"

fun! VexToggle(dir)
	if exists("t:vex_buf_nr")
		call VexClose()
	else 
		call VexOpen(a:dir)
	endif
endf

fun! VexOpen(dir)
	let g:netrw_browse_split=4
	let g:netrw_banner=0
	let vex_width = 25

	execute "Vexplore " . a:dir
	let t:vex_buf_nr = bufnr("%")
	wincmd H

	call VexSize(vex_width)
endf

fun! VexClose()
	let cur_win_nr = winnr()
	let target_nr = ( cur_win_nr == 1 ? winnr("#") : cur_win_nr )

	1wincmd w
	close
	unlet t:vex_buf_nr

	execute (target_nr - 1) . "wincmd w"
	call NormalizeWidths()

	let g:netrw_banner=1
endf

fun! VexSize(vex_width)
	execute "vertical resize" . a:vex_width
	set winfixwidth
	call NormalizeWidths()
endf

fun! NormalizeWidths()
	let eadir_pref = &eadirection
	set eadirection=hor
	set equalalways! equalalways!
	let &eadirection = eadir_pref
endf


