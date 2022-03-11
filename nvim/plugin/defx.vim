" Documentation: defx
"
" Press "K" on when cursor on top of defx

lua require("odas0r")

nnoremap \ :Defx -search=`expand('%:p')` `expand('%:p:h')`<CR>
function! DefxMappings()
  " open a file with left mouse click
	nnoremap <silent><buffer><expr> <2-LeftMouse> defx#do_action('open_tree', 'toggle')
  nnoremap <silent><buffer><expr> c
        \ defx#do_action('copy')
  nnoremap <silent><buffer><expr> m
        \ defx#do_action('move')
  nnoremap <silent><buffer><expr> p
        \ defx#do_action('paste')
  nnoremap <silent><buffer><expr> l
        \ defx#do_action('open_tree', 'toggle')
  nnoremap <silent><buffer><expr> <CR>
        \ defx#do_action('open')
  nnoremap <silent><buffer><expr> P
        \ defx#do_action('preview')
  nnoremap <silent><buffer><expr> d
        \ defx#do_action('new_directory')
  nnoremap <silent><buffer><expr> N
        \ defx#do_action('new_file')
  nnoremap <silent><buffer><expr> M
        \ defx#do_action('new_multiple_files')
  nnoremap <silent><buffer><expr> D
        \ defx#do_action('remove')
  nnoremap <silent><buffer><expr> R
        \ defx#do_action('rename')
  nnoremap <silent><buffer><expr> !
        \ defx#do_action('execute_command')
  " open directory on finder
  nnoremap <silent><buffer><expr> o
        \ defx#do_action('execute_system')
  nnoremap <silent><buffer><expr> yy
        \ defx#do_action('yank_path')
  nnoremap <silent><buffer><expr> .
        \ defx#do_action('toggle_ignored_files')
  nnoremap <silent><buffer><expr> h
        \ defx#do_action('cd', ['..'])
  nnoremap <silent><buffer><expr> q
        \ defx#do_action('quit')
  nnoremap <silent><buffer><expr> <Tab>
        \ defx#do_action('toggle_select') . 'j'
  nnoremap <silent><buffer><expr> <C-7>
        \ defx#do_action('toggle_select_all')
  nnoremap <silent><buffer><expr> j
        \ line('.') == line('$') ? 'gg' : 'j'
  nnoremap <silent><buffer><expr> k
        \ line('.') == 1 ? 'G' : 'k'
  nnoremap <silent><buffer><expr> <C-l>
        \ defx#do_action('redraw')
endfunction
autocmd FileType defx call DefxMappings()

" open defx automatically when :edit a directory
autocmd BufEnter,VimEnter,BufNew,BufWinEnter,BufRead,BufCreate
      \ * if isdirectory(expand('<amatch>'))
      \   | call s:browse_check(expand('<amatch>')) | endif

function! s:browse_check(path) abort
  if bufnr('%') != expand('<abuf>')
    return
  endif
  " Disable netrw.
  augroup FileExplorer
    autocmd!
  augroup END
  execute 'Defx' a:path
endfunction
