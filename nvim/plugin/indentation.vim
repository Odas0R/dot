" Indentation fixes, settings

function! IndentWithI()
    " if filetype is invalid don't indent (e.g terminal)
    if &filetype == ""
      return "i"
    endif

    " fix indentation
    if len(getline('.')) == 0
        return "\"_cc"
    else
        return "i"
    endif
endfunction

nnoremap <expr> i IndentWithI()
