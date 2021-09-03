let s:cpo_save = &cpo
set cpo&vim

" load configurations
call fsharp#loadConfig()

" auto setup nvim-lsp
let s:did_lsp_setup = 0
if g:fsharp#backend == 'nvim' && g:fsharp#lsp_auto_setup && !s:did_lsp_setup
    let s:did_lsp_setup = 1
    lua ionide.setup{}
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=4 et sts=4
