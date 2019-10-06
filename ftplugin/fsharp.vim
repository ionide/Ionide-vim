" Vim filetype plugin

if exists('b:did_fsharp_ftplugin')
    finish
endif
let b:did_fsharp_ftplugin = 1

let script_dir = expand('<sfile>:p:h')
let fsac = script_dir . "/../fsac/fsautocomplete.dll"

if empty(glob(fsac))
    echoerr "FSAC not found. :FSharpUpdateFSAC to download."
    finish
endif

" set some defaults
if !exists('g:fsharp#automatic_workspace_init')
    let g:fsharp#automatic_workspace_init = 1
endif
if !exists('g:fsharp#workspace_mode_peek_deep_level')
    let g:fsharp#workspace_mode_peek_deep_level = 2
endif
if !exists('g:fsharp#automatic_reload_workspace')
    let g:fsharp#automatic_reload_workspace = 1
endif
if !exists('g:fsharp#show_signature_on_cursor_move')
    let g:fsharp#show_signature_on_cursor_move = 1
endif
if !exists('g:fsharp#fsharp_interactive_command')
    let g:fsharp#fsharp_interactive_command = "dotnet fsi"
endif

let s:cpo_save = &cpo
set cpo&vim

" enable syntax based folding
setl fdm=syntax

" comment settings
setl formatoptions=croql
setl commentstring=(*%s*)
setl comments=s0:*\ -,m0:*\ \ ,ex0:*),s1:(*,mb:*,ex:*),:\/\/\/,:\/\/

" make ftplugin undo-able
let b:undo_ftplugin = 'setl fo< cms< com< fdm<'

if g:fsharp#automatic_workspace_init
    augroup LanguageClient_config
        autocmd!
        autocmd User LanguageClientStarted call fsharp#loadWorkspaceAuto()
    augroup END
endif

augroup FSharpLC_fs
    autocmd!
    autocmd CursorMoved *.fs,*.fsi,*.fsx  call fsharp#OnCursorMove()
augroup END

com! -buffer FSharpLoadWorkspaceAuto call fsharp#loadWorkspaceAuto()
com! -buffer FSharpReloadWorkspace call fsharp#reloadProjects()
com! -buffer -nargs=* FSharpUpdateFSAC call fsharp#updateFSAC(<f-args>)
com! -buffer -nargs=* -complete=file FSharpParseProject call fsharp#loadProject(<f-args>)

" TODO: :FsiEval :FsiEvalBuffer :FsiReset :FsiShow
com! -buffer -nargs=1 FsiEval call fsharp#sendFsi(<f-args>)
com! -buffer FsiEvalBuffer call fsharp#sendAllToFsi()
com! -buffer FsiReset call fsharp#resetFsi()
com! -buffer FsiShow call fsharp#openFsi()

" TODO: allow user to customize key binding for these commands
if has('nvim')
    vnoremap <silent> <M-cr> :call fsharp#sendSelectionToFsi()<cr><esc>
    nnoremap <silent> <M-cr> :call fsharp#sendLineToFsi()<cr>
    nnoremap <silent> <M-/>  :call fsharp#sendLineToFsi()<cr>
    nnoremap <silent> <M-@>  :call fsharp#toggleFsi()<cr>
    tnoremap <silent> <M-@>  <C-\><C-n>:call fsharp#toggleFsi()<cr>
else
    vnoremap <silent> <leader><cr> :call fsharp#sendSelectionToFsi()<cr><esc>
    nnoremap <silent> <leader><cr> :call fsharp#sendLineToFsi()<cr>
    nnoremap <silent> <leader></>  :call fsharp#sendLineToFsi()<cr>
    nnoremap <silent> <C-@>  :call fsharp#toggleFsi()<cr>
    tnoremap <silent> <C-@>  <C-\><C-n>:call fsharp#toggleFsi()<cr>
endif

let &cpo = s:cpo_save

" vim: sw=4 et sts=4
