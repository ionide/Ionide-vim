" Vim filetype plugin

if exists('b:did_fsharp_project_ftplugin')
    finish
endif
let b:did_fsharp_project_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

augroup FSharpLC_fsproj
  autocmd! BufWritePost *.fsproj call fsharp#OnFSProjSave()
augroup END

let &cpo = s:cpo_save

" vim: sw=4 et sts=4
