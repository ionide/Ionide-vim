" Vim autoload functions

if exists('g:loaded_autoload_fsharp')
    finish
endif
let g:loaded_autoload_fsharp = 1

let s:cpo_save = &cpo
set cpo&vim

function! s:prompt(msg)
    let height = &cmdheight
    if height < 2
        set cmdheight=2
    endif
    echom a:msg
    let &cmdheight = height
endfunction

function! s:PlainNotification(content)
    return { 'Content': a:content }
endfunction

function! s:TextDocumentIdentifier(path)
    let usr_ss_opt = &shellslash
    set shellslash
    let uri = fnamemodify(a:path, ":p")
    if uri[0] == "/"
        let uri = "file://" . uri
    else
        let uri = "file:///" . uri
    endif
    let &shellslash = usr_ss_opt
    return { 'Uri': uri }
endfunction

function! s:Position(line, character)
    return { 'Line': a:line, 'Character': a:character }
endfunction

function! s:TextDocumentPositionParams(documentUri, line, character)
    return {
        \ 'TextDocument': s:TextDocumentIdentifier(a:documentUri),
        \ 'Position':     s:Position(a:line, a:character)
        \ }
endfunction

function! s:DocumentationForSymbolRequest(xmlSig, assembly)
    return {
        \ 'XmlSig': a:xmlSig,
        \ 'Assembly': a:assembly
        \ }
endfunction

function! s:ProjectParms(projectUri)
    return { 'Project': s:TextDocumentIdentifier(a:projectUri) }
endfunction

function! s:WorkspacePeekRequest(directory, deep, excludedDirs)
    return {
        \ 'Directory': fnamemodify(a:directory, ":p"),
        \ 'Deep': a:deep,
        \ 'ExcludedDirs': a:excludedDirs
        \ }
endfunction

function! s:WorkspaceLoadParms(files)
    let prm = []
    for file in a:files
        call add(prm, s:TextDocumentIdentifier(file))
    endfor
    return { 'TextDocuments': prm }
endfunction

function! s:FsdnRequest(query)
    return { 'Query': a:query }
endfunction

function! s:call(method, params, cont)
    call LanguageClient#Call(a:method, a:params, a:cont)
endfunction

function! s:signature(filePath, line, character, cont)
    return s:call('fsharp/signature', s:TextDocumentPositionParams(a:filePath, a:line, a:character), a:cont)
endfunction
function! s:signatureData(filePath, line, character, cont)
    return s:call('fsharp/signatureData', s:TextDocumentPositionParams(a:filePath, a:line, a:character), a:cont)
endfunction
function! s:lineLens(projectPath, cont)
    return s:call('fsharp/lineLens', s:ProjectParms(a:projectPath), a:cont)
endfunction
function! s:compilerLocation(cont)
    return s:call('fsharp/compilerLocation', {}, a:cont)
endfunction
function! s:compile(projectPath, cont)
    return s:call('fsharp/compile', s:ProjectParms(a:projectPath), a:cont)
endfunction
function! s:workspacePeek(directory, depth, excludedDirs, cont)
    return s:call('fsharp/workspacePeek', s:WorkspacePeekRequest(a:directory, a:depth, a:excludedDirs), a:cont)
endfunction
function! s:workspaceLoad(files, cont)
    return s:call('fsharp/workspaceLoad', s:WorkspaceLoadParms(a:files), a:cont)
endfunction
function! s:project(projectPath, cont)
    return s:call('fsharp/project', s:ProjectParms(a:projectPath), a:cont)
endfunction
function! s:fsdn(signature, cont)
    return s:call('fsharp/fsdn', s:FsdnRequest(a:signature), a:cont)
endfunction
function! s:f1Help(filePath, line, character, cont)
    return s:call('fsharp/f1Help', s:TextDocumentPositionParams(a:filePath, a:line, a:character), a:cont)
endfunction
function! fsharp#documentation(filePath, line, character, cont)
    return s:call('fsharp/documentation', s:TextDocumentPositionParams(a:filePath, a:line, a:character), a:cont)
endfunction
function! s:documentationSymbol(xmlSig, assembly, cont)
    return s:call('fsharp/documentationSymbol', s:DocumentationForSymbolRequest(a:xmlSig, a:assembly), a:cont)
endfunction

function! s:findWorkspace(dir, cont)
    let s:cont_findWorkspace = a:cont
    function! s:callback_findWorkspace(result)
        let result = a:result
        let content = json_decode(result.result.content)
        if len(content.Data.Found) < 1
            return []
        endif
        let workspace = { 'Type': 'none' }
        for found in content.Data.Found
            if workspace.Type == 'none'
                let workspace = found
            elseif found.Type == 'solution'
                if workspace.Type == 'project' then
                    let workspace = found
                else
                    let curLen = len(workspace.Data.Items)
                    let newLen = len(found.Data.Items)
                    if newLen > curLen then
                        let workspace = found
                    endif
                endif
            endif
        endfor
        if workspace.Type == 'solution'
            call s:cont_findWorkspace([workspace.Data.Path])
        else
            call s:cont_findWorkspace(workspace.Data.Fsprojs)
        endif
    endfunction
    call s:workspacePeek(a:dir, g:fsharp#workspace_mode_peek_deep_level, [], function("s:callback_findWorkspace"))
endfunction

let s:workspace = []

function! s:load(arg)
    let s:loading_workspace = a:arg
    function! s:callback_load(_)
        echo "[FSAC] Workspace loaded: " . join(s:loading_workspace, ', ')
        let s:workspace = s:workspace + s:loading_workspace
    endfunction
    call s:workspaceLoad(a:arg, function("s:callback_load"))
endfunction

function! fsharp#loadProject(...)
    let prjs = []
    for proj in a:000
        call add(prjs, fnamemodify(proj, ':p'))
    endfor
    call s:load(prjs)
endfunction

function! fsharp#loadWorkspaceAuto()
    if &ft == 'fsharp'
        echom "[FSAC] Loading workspace..."
        let bufferDirectory = fnamemodify(resolve(expand('%:p')), ':h')
        call s:findWorkspace(bufferDirectory, function("s:load"))
    endif
endfunction

function! fsharp#reloadProjects()
    if len(s:workspace) > 0
        function! s:callback_reloadProjects(_)
            call s:prompt("[FSAC] Workspace reloaded.")
        endfunction
        call s:workspaceLoad(s:workspace, function("s:callback_reloadProjects"))
    else
        echom "[FSAC] Workspace is empty"
    endif
endfunction

function! fsharp#OnFSProjSave()
    if &ft == "fsharp_project" && g:fsharp#automatic_reload_workspace
        call fsharp#reloadProjects()
    endif
endfunction

function! fsharp#showSignature()
    function! s:callback_showSignature(result)
        let result = a:result
        if exists('result.result.content')
            let content = json_decode(result.result.content)
            if exists('content.Data')
                echom substitute(content.Data, '\n\+$', ' ', 'g')
            endif
        endif
    endfunction
    call s:signature(expand('%:p'), line('.') - 1, col('.') - 1, function("s:callback_showSignature"))
endfunction

function! fsharp#OnCursorMove()
    if g:fsharp#show_signature_on_cursor_move
        call fsharp#showSignature()
    endif
endfunction

function! fsharp#showF1Help()
    let result = s:f1Help(expand('%:p'), line('.') - 1, col('.') - 1)
    echo result
endfunction

let s:script_root_dir = expand('<sfile>:p:h') . "/../"
let s:fsac = fnamemodify(s:script_root_dir . "fsac/fsautocomplete.dll", ":p")
let g:fsharp#languageserver_command =
    \ ['dotnet', s:fsac, 
        \ '--background-service-enabled',
        \ '--mode', 'lsp'
    \ ]

function! s:download(branch)
    echom "[FSAC] Downloading FSAC."
    let zip = s:script_root_dir . "fsac.zip"
    call system(
        \ 'curl -fLo ' . zip .  ' --create-dirs ' .
        \ '"https://ci.appveyor.com/api/projects/fsautocomplete/fsautocomplete/artifacts/bin/pkgs/fsautocomplete.netcore.zip?branch=' . a:branch . '"'
        \ )
    if v:shell_error == 0
        call system('unzip -d ' . s:script_root_dir . "/fsac " . zip)
        echom "[FSAC] Updated FsAutoComplete to version " . a:branch . "" 
    else
        echom "[FSAC] Failed to update FsAutoComplete"
    endif
endfunction

function! fsharp#updateFSAC(...)
    if len(a:000) == 0
        let branch = "master"
    else
        let branch = a:000[0]
    endif
    call s:download(branch)
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=4 et sts=4
