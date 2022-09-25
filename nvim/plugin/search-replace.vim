" Took this code from here:
"
" https://gosukiwi.github.io/vim/2022/04/19/vim-advanced-search-and-replace.html

set grepprg=rg\ --vimgrep
set grepformat=%f:%l:%c:%m

if !exists('s:latest_greps')
  let s:latest_greps = {}
endif

function! s:Grep(...) abort
  let pattern = get(a:, 1, '')
  if pattern == '' | return | endif

  let s:latest_greps[pattern] = 1
  let path = get(a:, 2, '.')
  execute 'silent! grep! "' . escape(pattern, '"-') . '" ' . path . ' | redraw! | copen'
endfunction

function! s:Replace(original, replacement) abort
  if a:original == '' || a:replacement == '' | return | endif

  execute 'cfdo %s/' . escape(a:original, '/') . '/' . a:replacement . '/ge'
endfunction

function! LatestGreps(ArgLead, CmdLine, CursorPos)
  return keys(s:latest_greps)
endfunction

command! -nargs=+ -complete=file Grep silent! call s:Grep(<f-args>)
command! -nargs=+ -complete=customlist,LatestGreps Replace silent! call s:Replace(<f-args>)

" Mappings for grepping and replacing
"
" Examples:
"
" :Grep my-pattern % -- search on the current file
" :Grep my-pattern   -- search on the current project
nnoremap <Leader>G :Grep<Space>
nnoremap <silent> <Leader>r :call feedkeys(':Replace<Space><Tab>', 't')<CR>
