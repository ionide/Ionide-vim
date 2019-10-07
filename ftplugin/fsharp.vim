" Vim filetype plugin

if exists('b:did_fsharp_ftplugin')
    finish
endif
let b:did_fsharp_ftplugin = 1

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

com! -buffer -nargs=* FSharpUpdateFSAC call fsharp#updateFSAC(<f-args>)

" check if FSAC exists
let script_dir = expand('<sfile>:p:h')
let fsac = script_dir . "/../fsac/fsautocomplete.dll"
if empty(glob(fsac))
    echoerr "FSAC not found. :FSharpUpdateFSAC to download."
    let &cpo = s:cpo_save
    finish
endif

" add LanguageClient configuration

if !exists('g:LanguageClient_serverCommands')
    let g:LanguageClient_serverCommands = {}
endif
if !has_key(g:LanguageClient_serverCommands, 'fsharp')
    let g:LanguageClient_serverCommands.fsharp = g:fsharp#languageserver_command
endif

if g:fsharp#automatic_workspace_init
    augroup LanguageClient_config
        autocmd!
        autocmd User LanguageClientStarted call fsharp#loadWorkspaceAuto()
    augroup END
endif

augroup FSharpLC_fs
    autocmd! CursorMoved *.fs call fsharp#OnCursorMove()
augroup END

com! -buffer FSharpLoadWorkspaceAuto call fsharp#loadWorkspaceAuto()
com! -buffer FSharpReloadWorkspace call fsharp#reloadProjects()
com! -buffer -nargs=* -complete=file FSharpParseProject call fsharp#loadProject(<f-args>)

let &cpo = s:cpo_save

" vim: sw=4 et sts=4
