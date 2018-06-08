" F#, fsharp

" regexpengine=1 is for fast rendering of fsharp.vim syntax.
" regexpengine must be set before filetype setting.
if !has('nvim') && !has('gui_running')
    autocmd  BufNewFile,BufRead *.fs,*.fsi,*.fsx  set regexpengine=1
endif

autocmd BufNewFile,BufRead *.fs,*.fsi,*.fsx set filetype=fsharp
