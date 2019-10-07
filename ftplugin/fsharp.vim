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
if !exists('g:fsharp#fsi_command')
    let g:fsharp#fsi_command = "dotnet fsi"
endif
if !exists('g:fsharp#fsi_keymap')
    let g:fsharp#fsi_keymap = "vscode"
endif
if !exists('g:fsharp#fsi_window_command')
    let g:fsharp#fsi_window_command = "botright 10new"
endif
if !exists('g:fsharp#fsi_focus_on_send')
    let g:fsharp#fsi_focus_on_send = 0
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

com! -buffer -nargs=1 FsiEval call fsharp#sendFsi(<f-args>)
com! -buffer FsiEvalBuffer call fsharp#sendAllToFsi()
com! -buffer FsiReset call fsharp#resetFsi()
com! -buffer FsiShow call fsharp#openFsi()

if g:fsharp#fsi_keymap == "vscode"
    if has('nvim')
        let g:fsharp#fsi_keymap_send   = "<M-cr>"
        let g:fsharp#fsi_keymap_toggle = "<M-@>"
    else
        let g:fsharp#fsi_keymap_send   = "<esc><cr>"
        let g:fsharp#fsi_keymap_toggle = "<esc>@"
    endif
elseif g:fsharp#fsi_keymap == "vim-fsharp"
    let g:fsharp#fsi_keymap_send   = "<leader>i"
    let g:fsharp#fsi_keymap_toggle = "<leader>e"
elseif g:fsharp#fsi_keymap == "custom"
    let g:fsharp#fsi_keymap = "none"
    if !exists('g:fsharp#fsi_keymap_send')
        echoerr "g:fsharp#fsi_keymap_send is not set"
    elseif !exists('g:fsharp#fsi_keymap_toggle')
        echoerr "g:fsharp#fsi_keymap_toggle is not set"
    else
        let g:fsharp#fsi_keymap = "custom"
    endif
endif
if g:fsharp#fsi_keymap != "none"
    execute "vnoremap <silent>" g:fsharp#fsi_keymap_send ":call fsharp#sendSelectionToFsi()<cr><esc>"
    execute "nnoremap <silent>" g:fsharp#fsi_keymap_send ":call fsharp#sendLineToFsi()<cr>"
    execute "nnoremap <silent>" g:fsharp#fsi_keymap_toggle ":call fsharp#toggleFsi()<cr>"
    execute "tnoremap <silent>" g:fsharp#fsi_keymap_toggle "<C-\\><C-n>:call fsharp#toggleFsi()<cr>"
endif

let &cpo = s:cpo_save

" vim: sw=4 et sts=4
