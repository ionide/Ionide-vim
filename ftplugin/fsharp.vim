" Vim filetype plugin

if exists('b:did_fsharp_ftplugin')
    finish
endif
let b:did_fsharp_ftplugin = 1

let script_dir = expand('<sfile>:p:h')
let fsac = script_dir . "/../fsac/fsautocomplete.dll"

if empty(glob(fsac))
    echoerr "FSAC not found. :FSharpDownloadFSAC to download."
    finish
endif

" set some defaults
if !exists('g:fsharp#automatic_workspace_init')
    let g:fsharp#automatic_workspace_init = 1
endif
if !exists('g:fsharp#automatic_reload_workspace')
    let g:fsharp#automatic_reload_workspace = 1
endif
if !exists('g:fsharp#show_signature_on_cursor_move')
    let g:fsharp#show_signature_on_cursor_move = 1
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

augroup FSharpLC
    autocmd! CursorMoved <buffer> call fsharp#OnCursorMove()
augroup END

com! -buffer FSharpLoadWorkspaceAuto call fsharp#loadWorkspaceAuto()
com! -buffer FSharpReloadWorkspace call fsharp#reloadProjects()
com! -buffer -nargs=* -complete=file FSharpParseProject call fsharp#loadProject(<f-args>)

let &cpo = s:cpo_save

" vim: sw=4 et sts=4
