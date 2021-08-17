" Vim filetype plugin

if exists('b:did_fsharp_ftplugin')
    finish
endif
let b:did_fsharp_ftplugin = 1

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

if has('nvim-0.5')
    lua ionide = require("ionide")
endif

" load configurations
call fsharp#loadConfig()

" colorscheme for nvim-lsp
function! FSharpApplyRecommendedColorScheme()
    highlight! LspDiagnosticsDefaultError ctermbg=Red ctermfg=White
    highlight! LspDiagnosticsDefaultWarning ctermbg=Yellow ctermfg=Black
    highlight! LspDiagnosticsDefaultInformation ctermbg=LightBlue ctermfg=Black
    highlight! LspDiagnosticsDefaultHint ctermbg=Green ctermfg=White
    highlight! default link LspCodeLens Comment
endfunction

if g:fsharp#backend == 'nvim' && g:fsharp#lsp_recommended_colorscheme
    call FSharpApplyRecommendedColorScheme()
    augroup FSharp_ApplyRecommendedColorScheme
        autocmd!
        autocmd ColorScheme * call FSharpApplyRecommendedColorScheme()
    augroup END
endif

" F# specific bindings
if g:fsharp#backend == 'languageclient-neovim'
    augroup LanguageClient_config
        autocmd!
        autocmd User LanguageClientStarted call fsharp#initialize()
    augroup END
endif
if g:fsharp#backend != 'disable'
    com! -buffer FSharpUpdateFSAC call fsharp#updateFSAC()
    com! -buffer FSharpReloadWorkspace call fsharp#reloadProjects()
    com! -buffer FSharpShowLoadedProjects call fsharp#showLoadedProjects()
    com! -buffer -nargs=* -complete=file FSharpLoadProject call fsharp#loadProject(<f-args>)
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

" auto setup nvim-lsp
if g:fsharp#backend == 'nvim' && g:fsharp#lsp_auto_setup
    lua ionide.setup{}
endif

let &cpo = s:cpo_save

" vim: sw=4 et sts=4
