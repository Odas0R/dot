" Indentation fixes, settings

function! IndentWithI()
    if len(getline('.')) == 0
        return "\"_cc"
    else
        return "i"
    endif
endfunction

nnoremap <expr> i IndentWithI()
