" Vim filetype plugin

if exists('b:did_fsharp_ftplugin')
    finish
endif
let b:did_fsharp_ftplugin = 1

if has('nvim-0.5')
    lua ionide = require("ionide-vim")
endif

" FSAC server configuration
if !exists('g:fsharp#use_recommended_server_config')
    let g:fsharp#use_recommended_server_config = 1
endif
call fsharp#getServerConfig()

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

if !exists('g:fsharp#backend')
    if has('nvim-0.5')
        if exists('g:LanguageClient_loaded')
            let g:fsharp#backend = "languageclient-neovim"
        else
            let g:fsharp#backend = "nvim"
        endif
    else
        let g:fsharp#backend = "languageclient-neovim"
    endif
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

" backend configuration
if g:fsharp#backend == 'languageclient-neovim'
    if !exists('g:LanguageClient_serverCommands')
        let g:LanguageClient_serverCommands = {}
    endif
    if !has_key(g:LanguageClient_serverCommands, 'fsharp')
        let g:LanguageClient_serverCommands.fsharp = g:fsharp#languageserver_command
    endif

    if !exists('g:LanguageClient_rootMarkers')
        let g:LanguageClient_rootMarkers = {}
    endif
    if !has_key(g:LanguageClient_rootMarkers, 'fsharp')
        let g:LanguageClient_rootMarkers.fsharp = ['*.sln', '*.fsproj', '.git']
    endif
elseif g:fsharp#backend == 'nvim'
    call luaeval('ionide.setup(_A[1], _A[2])', [g:fsharp#languageserver_command, g:fsharp#automatic_workspace_init])
else
    if g:fsharp#backend != 'disable'
        echoerr "[FSAC] Invalid backend: " . g:fsharp#backend
    endif
endif

" F# specific bindings
if g:fsharp#backend == 'languageclient-neovim'
    if g:fsharp#automatic_workspace_init
        augroup LanguageClient_config
            autocmd!
            autocmd User LanguageClientStarted call fsharp#loadWorkspaceAuto()
        augroup END
    endif
elseif g:fsharp#backend != 'disable'
    " check if FSAC exists
    let script_dir = expand('<sfile>:p:h')
    let fsac = script_dir . "/../fsac/fsautocomplete.dll"
    if empty(glob(fsac))
        echoerr "FSAC not found. :FSharpUpdateFSAC to download."
        let &cpo = s:cpo_save
        finish
    endif

    augroup FSharpLC_fs
        autocmd!
        autocmd CursorMoved *.fs,*.fsi,*.fsx  call fsharp#OnCursorMove()
    augroup END

    com! -buffer FSharpUpdateFSAC call fsharp#updateFSAC()
    com! -buffer FSharpLoadWorkspaceAuto call fsharp#loadWorkspaceAuto()
    com! -buffer FSharpReloadWorkspace call fsharp#reloadProjects()
    com! -buffer -nargs=* -complete=file FSharpParseProject call fsharp#loadProject(<f-args>)
    com! -buffer FSharpUpdateServerConfig call fsharp#updateServerConfig()
endif

com! -buffer -nargs=1 FsiEval call fsharp#sendFsi(<f-args>)
com! -buffer FsiEvalBuffer call fsharp#sendAllToFsi()
com! -buffer FsiReset call fsharp#resetFsi()
com! -buffer FsiShow call fsharp#toggleFsi()

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
