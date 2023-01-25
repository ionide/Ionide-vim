local vim = vim
local validate = vim.validate
local api = vim.api
local uc = vim.api.nvim_create_user_command
local lsp = vim.lsp
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local tbl_extend = vim.tbl_extend

local function try_require(...)
  local status, lib = pcall(require, ...)
  if (status) then return lib end
  return nil
end

local lspconfig_is_present = true
local util = try_require('lspconfig.util')
if util == nil then
  lspconfig_is_present = false
  util = require('ionide.util')
end

local M = {}

local callbacks = {}
M.CallBackResults = {}

M.workspace_folders = {}
M.RegisterCallback = function(fn)
  if M.Backend ~= 'nvim' then
    return -1
  end
  local rnd = os.time()

  callbacks[rnd] = fn
  M.CallBackResults[rnd] = fn
  return rnd
end

M.ResolveCallback = function(key, arg)
  if M.Backend ~= 'nvim' then
    return
  end
  if callbacks[key] then
    local callback = callbacks[key]
    callback(arg)
    callbacks[key] = nil
  end
end

--  function! s:PlainNotification(content)
--    return { 'Content': a:content }
-- endfunction

M.PlainNotification = function(content)
  return { Content = content }
end

-- function! s:TextDocumentIdentifier(path)
--     let usr_ss_opt = &shellslash
--     set shellslash
--     let uri = fnamemodify(a:path, ":p")
--     if uri[0] == "/"
--         let uri = "file://" . uri
--     else
--         let uri = "file:///" . uri
--     endif
--     let &shellslash = usr_ss_opt
--     return { 'Uri': uri }
-- endfunction

M.TextDocumentIdentifier = function(path)
  local usr_ss_opt = vim.o.shellslash
  vim.o.shellslash = true
  local uri = vim.fn.fnamemodify(path, ":p")
  if string.sub(uri, 1, 1) == '/' then
    uri = "file://" .. uri
  else
    uri = "file:///" .. uri
  end
  vim.o.shellslash = usr_ss_opt
  return { Uri = uri }
end

-- function! s:Position(line, character)
--     return { 'Line': a:line, 'Character': a:character }
-- endfunction

M.Position = function(line, character)
  return { Line = line, Character = character }
end

-- function! s:TextDocumentPositionParams(documentUri, line, character)
--     return {
--         \ 'TextDocument': s:TextDocumentIdentifier(a:documentUri),
--         \ 'Position':     s:Position(a:line, a:character)
--         \ }
-- endfunction

M.TextDocumentPositionParams = function(documentUri, line, character)
  return {
    TextDocument = M.TextDocumentIdentifier(documentUri),
    Position = M.Position(line, character)
  }
end

-- function! s:DocumentationForSymbolRequest(xmlSig, assembly)
--     return {
--         \ 'XmlSig': a:xmlSig,
--         \ 'Assembly': a:assembly
--         \ }
-- endfunction

M.DocumentationForSymbolRequest = function(xmlSig, assembly)
  return {
    XmlSig = xmlSig,
    Assembly = assembly
  }
end

-- function! s:ProjectParms(projectUri)
--     return { 'Project': s:TextDocumentIdentifier(a:projectUri) }
-- endfunction

M.ProjectParms = function(projectUri)
  return {
    Project = M.TextDocumentIdentifier(projectUri),
  }
end

-- function! s:WorkspacePeekRequest(directory, deep, excludedDirs)
--     return {
--         \ 'Directory': fnamemodify(a:directory, ":p"),
--         \ 'Deep': a:deep,
--         \ 'ExcludedDirs': a:excludedDirs
--         \ }
-- endfunction


M.WorkspacePeekRequest = function(directory, deep, excludedDirs)
  return {
    Directory = string.gsub(directory, '\\', '/'),
    Deep = deep,
    ExcludedDirs = excludedDirs
  }
end

-- function! s:FsdnRequest(query)
--     return { 'Query': a:query }
-- endfunction

M.FsdnRequest = function(query)
  return { Query = query }
end

-- function! s:WorkspaceLoadParms(files)
--     let prm = []
--     for file in a:files
--         call add(prm, s:TextDocumentIdentifier(file))
--     endfor
--     return { 'TextDocuments': prm }
-- endfunction

M.WorkspaceLoadParms = function(files)
  local prm = {}
  for _, file in ipairs(files) do
    table.insert(prm, M.TextDocumentIdentifier(file))
  end
  return { TextDocuments = prm }
end

local function toSnakeCase(str)
  local snake = str:gsub("%u", function(ch) return "_" .. ch:lower() end)
  return snake:gsub("^_", "")
end

local function buildConfigKeys(camels)
  local keys = {}
  for _, c in ipairs(camels) do
    local key =
    function()
      if c.default then
        return {
          snake = toSnakeCase(c.key),
          camel = c.key,
          default = c.default
        }
      else
        return {
          snake = toSnakeCase(c.key),
          camel = c.key,
        }
      end
    end
    table.insert(keys, key())
  end
  return keys
end

M.Call = function(method, params, callback_key)
  -- local register = M.RegisterCallback(callback_key)
  local handler = function(err, result, ctx, config)
    vim.notify("result is: " .. vim.inspect({
      result = vim.inspect(result or "NO result"),
      err = vim.inspect(err or "NO err"),
      client_id = vim.inspect(ctx.client_id or "NO ctx clientid  "),
      bufnr = vim.inspect(ctx.bufnr or "NO ctx clientid  ")
    }))
    if result ~= nil then
      -- vim.notify("result is: " .. vim.inspect(result))
      M.ResolveCallback(callback_key, {
        result = result,
        err = err,
        client_id = ctx.client_id,
        bufnr = ctx.bufnr
      })
    end
  end
  -- if method == "fsharp/compilerLocation" then
  vim.notify("requesting method called '" ..
    method .. "' with " .. vim.inspect(params or "NO PARAMS Given") .. "with callback key of: " .. callback_key)
  -- end
  local request = lsp.buf_request(0, method, params, handler)
  if request then
    -- vim.notify("request gave : " .. vim.inspect(request))
    if callbacks[request] then
      -- vim.notify("request was found in callbacks: " .. vim.inspect(callbacks[request]))
    end
  end
end

M.Notify = function(method, params)
  lsp.buf_notify(0, method, params)
end

workspace_folders = {}


M.Signature = function(filePath, line, character, cont)
  return M.Call('fsharp/signature', M.TextDocumentPositionParams(filePath, line, character),
    cont)
end

M.SignatureData = function(filePath, line, character, cont)
  return M.Call('fsharp/signatureData', M.TextDocumentPositionParams(filePath, line, character)
    , cont)
end

M.LineLens = function(projectPath, cont)
  return M.Call('fsharp/lineLens', M.ProjectParms(projectPath), cont)
end

M.CompilerLocation = function(cont)
  return M.Call('fsharp/compilerLocation', {}, cont)
end

uc('IonideCompilerLocation',
  function()
    -- local cb = M.RegisterCallback(M.CompilerLocation)
    -- local rcb = M.ResolveCallback(cb,{})
    -- vim.notify(vim.inspect(rcb()))
    local key = os.time()
    vim.notify("Calling for CompilerLocations with timekey of " .. vim.inspect(key))
    return M.Call('fsharp/compilerLocation', M.PlainNotification({}), key)
    -- M.CompilerLocation(key)
    -- vim.notify(vim.inspect(M.Call('fsharp/compilerLocation', {}, os.time())))
  end
  , { nargs = 0, desc = "Get compiler location data from FSAC" })

M.Compile = function(projectPath, cont)
  return M.Call('fsharp/compile', M.ProjectParms(projectPath), cont)
end

M.WorkspacePeek = function(directory, depth, excludedDirs, cont)
  return M.Call('fsharp/workspacePeek', M.WorkspacePeekRequest(directory, depth, excludedDirs),
    cont)
end

M.WorkspaceLoad = function(files, cont)
  return M.Call('fsharp/workspaceLoad', M.WorkspaceLoadParms(files), cont)
end

M.Project = function(projectPath, cont)
  return M.Call('fsharp/project', M.ProjectParms(projectPath), cont)
end

M.Fsdn = function(signature, cont)
  return M.Call('fsharp/fsdn', M.FsdnRequest(signature), cont)
end

M.F1Help = function(filePath, line, character, cont)
  return M.Call('fsharp/f1Help', M.TextDocumentPositionParams(filePath, line, character), cont)
end

M.Documentation = function(filePath, line, character, cont)
  return M.Call('fsharp/documentation', M.TextDocumentPositionParams(filePath, line, character)
    , cont)
end

M.DocumentationSymbol = function(xmlSig, assembly, cont)
  return M.Call('fsharp/documentationSymbol', M.DocumentationForSymbolRequest(xmlSig, assembly)
    , cont)
end

-- from https://github.com/fsharp/FsAutoComplete/blob/main/src/FsAutoComplete/LspHelpers.fs
-- FSharpConfigDto =
--   { AutomaticWorkspaceInit: bool option
--     WorkspaceModePeekDeepLevel: int option
--     ExcludeProjectDirectories: string[] option
--     KeywordsAutocomplete: bool option
--     ExternalAutocomplete: bool option
--     Linter: bool option
--     LinterConfig: string option
--     IndentationSize: int option
--     UnionCaseStubGeneration: bool option
--     UnionCaseStubGenerationBody: string option
--     RecordStubGeneration: bool option
--     RecordStubGenerationBody: string option
--     InterfaceStubGeneration: bool option
--     InterfaceStubGenerationObjectIdentifier: string option
--     InterfaceStubGenerationMethodBody: string option
--     UnusedOpensAnalyzer: bool option
--     UnusedDeclarationsAnalyzer: bool option
--     SimplifyNameAnalyzer: bool option
--     ResolveNamespaces: bool option
--     EnableReferenceCodeLens: bool option
--     EnableAnalyzers: bool option
--     AnalyzersPath: string[] option
--     DisableInMemoryProjectReferences: bool option
--     LineLens: LineLensConfig option
--     UseSdkScripts: bool option
--     DotNetRoot: string option
--     FSIExtraParameters: string[] option
--     FSICompilerToolLocations: string[] option
--     TooltipMode: string option
--     GenerateBinlog: bool option
--     AbstractClassStubGeneration: bool option
--     AbstractClassStubGenerationObjectIdentifier: string option
--     AbstractClassStubGenerationMethodBody: string option
--     CodeLenses: CodeLensConfigDto option
--     InlayHints: InlayHintDto option
--     Debug: DebugDto option }
--
-- type FSharpConfigRequest = { FSharp: FSharpConfigDto }
local function getServerConfig()
  local config = {}
  local camels = {
    --   { AutomaticWorkspaceInit: bool option
    --AutomaticWorkspaceInit = false
    { key = "AutomaticWorkspaceInit", default = true },
    --     WorkspaceModePeekDeepLevel: int option
    --WorkspaceModePeekDeepLevel = 2
    { key = "WorkspaceModePeekDeepLevel", default = 4 },
    --     ExcludeProjectDirectories: string[] option
    -- = [||]
    { key = "ExcludeProjectDirectories", default = {} },
    --     KeywordsAutocomplete: bool option
    -- false
    { key = "KeywordsAutocomplete", default = true },
    --     ExternalAutocomplete: bool option
    --false
    { key = "ExternalAutocomplete", default = false },
    --     Linter: bool option
    --false
    { key = "Linter", default = true },
    --     IndentationSize: int option
    --4
    { key = "IndentationSize", default = 2 },
    --     UnionCaseStubGeneration: bool option
    --false
    { key = "UnionCaseStubGeneration", default = true },
    --     UnionCaseStubGenerationBody: string option
    --    """failwith "Not Implemented" """
    { key = "UnionCaseStubGenerationBody", default = "failwith \"Not Implemented\"" },
    --     RecordStubGeneration: bool option
    --false
    { key = "RecordStubGeneration", default = true },
    --     RecordStubGenerationBody: string option
    -- "failwith \"Not Implemented\""
    { key = "RecordStubGenerationBody", default = "failwith \"Not Implemented\"" },
    --     InterfaceStubGeneration: bool option
    --false
    { key = "InterfaceStubGeneration", default = true },
    --     InterfaceStubGenerationObjectIdentifier: string option
    -- "this"
    { key = "InterfaceStubGenerationObjectIdentifier", default = "this" },
    --     InterfaceStubGenerationMethodBody: string option
    -- "failwith \"Not Implemented\""
    { key = "InterfaceStubGenerationMethodBody", default = "failwith \"Not Implemented\"" },
    --     UnusedOpensAnalyzer: bool option
    --false
    { key = "UnusedOpensAnalyzer", default = true },
    --     UnusedDeclarationsAnalyzer: bool option
    --false
    --
    { key = "UnusedDeclarationsAnalyzer", default = true },
    --     SimplifyNameAnalyzer: bool option
    --false
    --
    { key = "SimplifyNameAnalyzer", default = true },
    --     ResolveNamespaces: bool option
    --false
    --
    { key = "ResolveNamespaces", default = true },
    --     EnableReferenceCodeLens: bool option
    --false
    --
    { key = "EnableReferenceCodeLens", default = true },
    --     EnableAnalyzers: bool option
    --false
    --
    { key = "EnableAnalyzers", default = true },
    --     AnalyzersPath: string[] option
    --
    { key = "AnalyzersPath" },
    --     DisableInMemoryProjectReferences: bool option
    --false|
    --
    { key = "DisableInMemoryProjectReferences", default = false },
    --     LineLens: LineLensConfig option
    --
    { key = "LineLens", default = { enabled = "always", prefix = "//" } },
    --     UseSdkScripts: bool option
    --false
    --
    { key = "UseSdkScripts", default = true },
    --     DotNetRoot: string option  Environment.dotnetSDKRoot.Value.FullName
    --
    { key = "DotNetRoot", default =

    (function()
      local function find_executable(name)
        local path = os.getenv("PATH") or ""
        for dir in string.gmatch(path, "[^:]+") do
          local executable = dir .. "/" .. name .. ".exe"
          if os.execute("test -x " .. executable) == 1 then
            return dir .. "/"
          end
        end
        return nil
      end

      local dnr = os.getenv("DOTNET_ROOT")
      if dnr and not dnr == "" then
        return dnr
      else
        if vim.fn.has("win32") then
          local canExecute = vim.fn.executable("dotnet") == 1
          if not canExecute then
            local vs1 = vim.fs.find({ "fscAnyCpu.exe" },
              { path = "C:/Program Files/Microsoft Visual Studio", type = "file" })
            local vs2 = vim.fs.find({ "fscAnyCpu.exe" },
              { path = "C:/Program Files (x86)/Microsoft Visual Studio", type = "file" })
            return vs1 or vs2 or ""
          else
            local dn = vim.fs.find({ "dotnet.exe" }, { path = "C:/Program Files/dotnet/", type = "file" })
            return dn or find_executable("dotnet") or ""
          end
        else
          return ""
        end
        return ""
      end
    end)()
    },
    --     FSIExtraParameters: string[] option
    --     j
    { key = "FSIExtraParameters", default = {} },
    --     FSICompilerToolLocations: string[] option
    --
    { key = "FSICompilerToolLocations", default = {} },
    --     TooltipMode: string option
    --TooltipMode = "full"
    { key = "TooltipMode", default = "full" },
    --     GenerateBinlog: bool option
    -- GenerateBinlog = false
    { key = "GenerateBinlog", default = false },
    --     AbstractClassStubGeneration: bool option
    -- AbstractClassStubGeneration = true
    { key = "AbstractClassStubGeneration", default = true },
    --     AbstractClassStubGenerationObjectIdentifier: string option
    -- AbstractClassStubGenerationObjectIdentifier = "this"
    { key = "AbstractClassStubGenerationObjectIdentifier", default = "this" },
    --     AbstractClassStubGenerationMethodBody: string option, default = "failwith \"Not Implemented\""
    -- AbstractClassStubGenerationMethodBody = "failwith \"Not Implemented\""
    --
    { key = "AbstractClassStubGenerationMethodBody", default = "failwith \"Not Implemented\"" },
    --     CodeLenses: CodeLensConfigDto option
    --  type CodeLensConfigDto =
    -- { Signature: {| Enabled: bool option |} option
    --   References: {| Enabled: bool option |} option }
    { key = "CodeLenses",
      default = {
        Signature = {
          Enabled = true
        },
        References = {
          Enabled = true
        },
      },
    },
    --     InlayHints: InlayHintDto option
    --type InlayHintsConfig =
    -- { typeAnnotations: bool
    -- parameterNames: bool
    -- disableLongTooltip: bool }
    -- static member Default =
    --   { typeAnnotations = true
    --     parameterNames = true
    --     disableLongTooltip = true }

    { key = "InlayHints",
      default = {
        typeAnnotations = true,
        parameterNames = true,
        disableLongTooltip = true,
      },
    },

    --     Debug: DebugDto option }
    --   type DebugConfig =
    -- { DontCheckRelatedFiles: bool
    --   CheckFileDebouncerTimeout: int
    --   LogDurationBetweenCheckFiles: bool
    --   LogCheckFileDuration: bool }
    --
    -- static member Default =
    --   { DontCheckRelatedFiles = false
    --     CheckFileDebouncerTimeout = 250
    --     LogDurationBetweenCheckFiles = false
    --     LogCheckFileDuration = false }
    --       }
    { key = "Debug",
      default =
      { DontCheckRelatedFiles = false,
        CheckFileDebouncerTimeout = 250,
        LogDurationBetweenCheckFiles = false,
        LogCheckFileDuration = false,
      },
    },

  }

  local keys = buildConfigKeys(camels)
  for _, key in ipairs(keys) do

    -- if not M[key.snake] then
    -- M[key.snake] = key.default
    -- end

    if not M[key.camel] then
      M[key.camel] = key.default
    end
    -- if not vim.g[key.snake] then
    --   vim.g[key.snake] = key.default or ""
    -- end
    if not config[key.camel] then
      config[key.camel] = key.default
    end
    if vim.g[key.snake] then
      config[key.camel] = vim.g[key.snake]
    elseif vim.g[key.camel] then
      config[key.camel] = vim.g[key.snake]
    elseif key.default and M.UseRecommendedServerConfig then
      vim.g[key.camel] = key.default
      vim.g[key.snake] = key.default
      config[key.camel] = key.default
    end
  end
  -- vim.notify("ionide config is " .. vim.inspect(config))
  return config
end

M.UpdateServerConfig = function()

  local fsharp = getServerConfig()
  -- vim.notify("ionide config is " .. vim.inspect(fsharp))
  local settings = { settings = { FSharp = fsharp } }
  M.Notify("workspace/didChangeConfiguration", settings)
end

local addThenSort = function(value, tbl)
  if not vim.tbl_contains(tbl, value) then
    table.insert(tbl, value)
    table.sort(tbl)
  end
  -- print("after sorting table, it now looks like this : " .. vim.inspect(tbl))
  return tbl
end


--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
M.HandleDocumentHighlight = function(range, kind)
  local u = require("vim.lsp.util")

  u.buf_highlight_references(0, range or {}, "utf-16")
end

M.HandleNotifyWorkspace = function(payload)
  -- vim.notify("handling notifyWorkspace")
  local content = vim.json.decode(payload.content)
  if content then
    if content.Kind == 'projectLoading' then
      vim.notify("[Ionide] Loading " .. content.Data.Project)
      -- print("[Ionide] now calling AddOrUpdateThenSort on table  " .. vim.inspect(Workspace))
      M.workspace_folders = addThenSort(content.Data.Project, M.workspace_folders)
      -- print("after attempting to reassign table value it looks like this : " .. vim.inspect(Workspace))
    elseif content.Kind == 'workspaceLoad' and content.Data.Status == 'finished' then
      -- print("[Ionide] calling updateServerConfig ... ")
      -- print("[Ionide] before calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
      M.UpdateServerConfig()
      -- print("[Ionide] after calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
      vim.notify("[Ionide] Workspace loaded (" .. #M.workspace_folders .. " project(s))")
    end
  end
end

function M.HandleCompilerLocationn(result)
  -- vim.notify("handling compilerLocation response\n" .. "result is: \n" .. vim.inspect(result or "Nothing came back from the server.."))
  vim.notify("handling compilerLocation response\n" ..
    "result is: \n" .. vim.inspect(vim.json.decode(result.content) or "Nothing came back from the server.."))
  -- local content = vim.json.decode(payload.content)
  -- if content then

  -- vim.notify(vim.inspect(content))
  -- if content.Kind == 'projectLoading' then
  --   print("[Ionide] Loading " .. content.Data.Project)
  --   -- print("[Ionide] now calling AddOrUpdateThenSort on table  " .. vim.inspect(Workspace))
  --   Workspace = addThenSort(content.Data.Project, Workspace)
  --   -- print("after attempting to reassign table value it looks like this : " .. vim.inspect(Workspace))
  -- elseif content.Kind == 'workspaceLoad' and content.Data.Status == 'finished' then
  --   print("[Ionide] calling updateServerConfig ... ")
  --   -- print("[Ionide] before calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
  --   M.UpdateServerConfig()
  --   -- print("[Ionide] after calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
  --   print("[Ionide] Workspace loaded (" .. #Workspace .. " project(s))")
  -- end
  -- end
end

local handlers = {
  ['fsharp/notifyWorkspace'] = "HandleNotifyWorkspace",
  ['textDocument/documentHighlight'] = "HandleDocumentHighlight",
  ['fsharp/compilerLocation'] = "HandleCompilerLocation"
}

local function GetHandlers()
  return handlers
end

M.CreateHandlers = function()

  local h = GetHandlers()
  local r = {}
  for method, func_name in pairs(h) do
    local handler = function(err, params, ctx, _config)


      -- if err then
      --   -- LSP spec:
      --   -- interface ResponseError:
      --   --  code: integer;
      --   --  message: string;
      --   --  data?: string | number | boolean | array | object | null;
      --   -- Per LSP, don't show ContentModified error to the user.
      --   if err.code ~= protocol.ErrorCodes.ContentModified and func_name then
      --
      --     local client = vim.lsp.get_client_by_id(ctx.client_id)
      --     local client_name = client and client.name or string.format('client_id=%d', ctx.client_id)
      --
      --     err_message(client_name .. ': ' .. tostring(err.code) .. ': ' .. err.message)
      --   end
      --   return
      -- end

      -- if params == nil or not (method == ctx.method) then return end
      M[func_name](params)
    end

    r[method] = handler
  end
  M.Handlers = r
  return r
end

local function load(arg)
  M.WorkspaceLoad(arg, nil)
end

M.LoadProject = function(...)
  local prjs = {}
  for _, proj in ipairs({ ... }) do
    table.insert(prjs, util.fnamemodify(proj, ':p'))
  end
  load(prjs)
end

M.ShowLoadedProjects = function()
  for _, proj in ipairs(workspace_folders) do
    print("- " .. proj)
  end
end

M.ReloadProjects = function()
  if #workspace_folders > 0 then
    M.WorkspaceLoad(workspace_folders, nil)
  else
    print("[Ionide] Workspace is empty")
  end
end

M.OnFSProjSave = function()
  if vim.bo.ft == "fsharp_project" and M.AutomaticReloadWorkspace and M.AutomaticReloadWorkspace == true then
    vim.notify("fsharp project saved, reloading...")
    M.ReloadProjects()
  end
end

M.LoadConfig = function()

  local generalConfigs = {

    FsautocompleteCommand = { "fsautocomplete", "--adaptive-lsp-server-enabled", "-v" },
    UseRecommendedServerConfig = true,
    AutomaticWorkspaceInit = true,
    AutomaticReloadWorkspace = true,
    ShowSignatureOnCursorMove = true,
    FsiCommand = "dotnet fsi",
    FsiKeymap = "vscode",
    FsiWindowCommand = "botright 10new",
    FsiFocusOnSend = false,
    Backend = "nvim",
    LspAutoSetup = false,
    LspRecommendedColorscheme = true,
    LspCodelens = true,
    FsiVscodeKeymaps = true,
    Statusline = "Ionide",
    AutocmdEvents = { "BufEnter", "BufWritePost", "CursorHold", "CursorHoldI", "InsertEnter", "InsertLeave" },
    FsiKeymapSend = "<M-cr>",
    FsiKeymapToggle = "<M-@>",

  }
  for key, v in pairs(generalConfigs) do
    local k = toSnakeCase(key)
    if not vim.g["fsharp#" .. k] then
      vim.g["fsharp#" .. k] = v
    end
    if not M[k] then M[k] = vim.g["fsharp#" .. k] end
  end
  return getServerConfig()
end

-- function! fsharp#showSignature()
--     function! s:callback_showSignature(result)
--         let result = a:result
--         if exists('result.result.content')
--             let content = json_decode(result.result.content)
--             if exists('content.Data')
--                 echo substitute(content.Data, '\n\+$', ' ', 'g')
--             endif
--         endif
--     endfunction
--     call s:signature(expand('%:p'), line('.') - 1, col('.') - 1, function("s:callback_showSignature"))
-- endfunction


M.ShowSignature = function()
  local cbShowSignature = function(result)
    if result then
      if result.result then
        if result.result.content then
          local content = vim.json.decode(result.result.content)
          if content then
            if content.Data then
              -- Using gsub() instead of substitute() in Lua
              -- and % instead of :
              print(content.Data:gsub("\n+$", " "))
            end
          end
        end
      end
    end
  end

  M.Signature(vim.fn.expand("%:p"), vim.cmd.line('.') - 1, vim.cmd.col('.') - 1,
    cbShowSignature)
end

-- function! fsharp#OnCursorMove()
--     if g:fsharp#show_signature_on_cursor_move
--         call fsharp#showSignature()
--     endif
-- endfunction
--
M.OnCursorMove = function()
  if M.ShowSignatureOnCursorMove then
    M.ShowSignature()
  end
end


M.RegisterAutocmds = function()
  --     if g:fsharp#backend == 'nvim' && g:fsharp#lsp_codelens
  if M.Backend == 'nvim' and (M.LspCodelens == true or M.LspCodelens == 1) then
    -- print("fsharp.backend is nvim and lsp_codelens is true.. ")
    local autocmd = vim.api.nvim_create_autocmd
    local grp = vim.api.nvim_create_augroup


    autocmd({ "CursorHold,InsertLeave" }, {
      desc = "FSharp Auto refresh code lens ",
      group = grp("FSharp_AutoRefreshCodeLens", { clear = true }),
      pattern = "*.fs,*.fsi,*.fsx",
      callback = function() vim.lsp.codelens.refresh() end,
    })

    autocmd({ "CursorHold,InsertLeave" }, {
      desc = "URL Highlighting",
      group = grp("FSharp_AutoRefreshCodeLens", { clear = true }),
      pattern = "*.fs,*.fsi,*.fsx",
      callback = M.OnCursorMove(),
    })
  end
end

M.Initialize = function()
  print 'Ionide Initializing'
  print 'Ionide calling updateServerConfig...'
  M.UpdateServerConfig()
  print 'Ionide calling SetKeymaps...'
  M.SetKeymaps()
  print 'Ionide calling registerAutocmds...'
  M.RegisterAutocmds()
  print 'Ionide Initialized'
end

local local_root_dir = function(n)
  local root
  root = util.find_git_ancestor(n)
  root = root or util.root_pattern("*.sln")(n)
  root = root or util.root_pattern("*.fsproj")(n)
  root = root or util.root_pattern("*.fsx")(n)
  return root
end

local function get_default_config()
  local config = M.LoadConfig()
  local result = {
    name = "ionide",
    cmd = { 'fsautocomplete', '--adaptive-lsp-server-enabled', '-v' },
    cmd_env = { DOTNET_ROLL_FORWARD = "LatestMajor" },
    filetypes = { "fsharp" },
    autostart = true,
    handlers = M.CreateHandlers(),
    init_options = { AutomaticWorkspaceInit = M.AutomaticWorkspaceInit },
    on_init = M.Initialize,
    settings = { FSharp = config },
    root_dir = local_root_dir,
    -- root_dir = util.root_pattern("*.sln"),
  }
  -- vim.notify("ionide default settings are : " .. vim.inspect(result))
  return result
end

M.Manager = nil

local function autostart_if_needed(m, config)
  local auto_setup = (M.LspAutoSetup == 1)
  if auto_setup and not (config.autostart == false) then
    m.autostart()
  end
end

local function delegate_to_lspconfig(config)
  local lspconfig = require('lspconfig')
  local configs = require('lspconfig.configs')
  if not (configs['ionide']) then
    configs['ionide'] = {
      default_config = get_default_config(),
      docs = {
        description = [[
            https://github.com/willehrendreich/Ionide-vim
                  ]],
      },
    }
  end
  lspconfig.ionide.setup(config)
end

--- ftplugin section ---
vim.filetype.add(
  {
    extension = {
      fsproj = function(path, bufnr)
        return 'fsharp_project', function(bufnr)
          vim.bo[bufnr].syn = "xml"
          vim.bo[bufnr].ro = false
          vim.b[bufnr].readonly = false
          vim.bo[bufnr].commentstring = "<!--%s-->"
          vim.bo[bufnr].comments = "<!--,e:-->"
          vim.opt_local.foldlevelstart = 99
          vim.w.fdm = 'syntax'
        end
      end,
    },
  })

vim.filetype.add(
  {
    extension = {
      fs = function(path, bufnr)
        return 'fsharp', function(bufnr)

          if not vim.g.filetype_fs then
            vim.g['filetype_fs'] = 'fsharp'
          end
          if not vim.g.filetype_fs == 'fsharp' then
            vim.g['filetype_fs'] = 'fsharp'
          end
          -- if vim.b.did_fsharp_ftplugin and vim.b.did_fsharp_ftplugin == 1 then
          -- return
          -- end

          -- vim.b.did_fsharp_ftplugin = 1

          -- local cpo_save = vim.o.cpo
          -- vim.o.cpo = ''
          --
          -- enable syntax based folding
          vim.w.fdm = 'syntax'

          -- comment settings
          vim.bo[bufnr].formatoptions = 'croql'
          vim.bo[bufnr].commentstring = '(*%s*)'
          vim.bo[bufnr].comments = [[s0:*\ -,m0:*\ \ ,ex0:*),s1:(*,mb:*,ex:*),:\/\/\/,:\/\/]]

          -- make ftplugin undo-able
          -- vim.bo[bufnr].undo_ftplugin = 'setl fo< cms< com< fdm<'

          -- local function prompt(msg)
          --   local height = vim.o.cmdheight
          --   if height < 2 then
          --     vim.o.cmdheight = 2
          --   end
          --   print(msg)
          --   vim.o.cmdheight = height
          -- end

          -- vim.o.cpo = cpo_save



        end
      end,
    },
  })

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.fsproj",
  desc = "FSharp Auto refresh on project save",
  group = vim.api.nvim_create_augroup("FSharpLCFsProj", { clear = true }),
  callback = function() M.OnFSProjSave() end
})

-- vim.api.nvim_create_autocmd("BufWritePost", {
--   pattern = "*.fsproj",
--   desc = "FSharp Auto refresh on project save",
--   group = vim.api.nvim_create_augroup("FSharpLCFsProj", { clear = true }),
--   callback = function() M.OnFSProjSave() end
-- })

--augroup FSharpLC_fsproj
-- autocmd! BufWritePost *.fsproj call fsharp#OnFSProjSave()
--augroup END
---- end ftplugin section ----



local function create_manager(config)
  validate {
    cmd = { config.cmd, "t", true },
    root_dir = { config.root_dir, "f", true },
    filetypes = { config.filetypes, "t", true },
    on_attach = { config.on_attach, "f", true },
    on_new_config = { config.on_new_config, "f", true },
  }

  local default_config = tbl_extend("keep", get_default_config(), util.default_config)
  config = tbl_extend("keep", config, default_config)

  local trigger
  if config.filetypes then
    trigger = "FileType " .. table.concat(config.filetypes, ",")
  else
    trigger = "BufReadPost *"
  end

  local get_root_dir = config.root_dir

  function M.Autostart()
    local root_dir = get_root_dir(api.nvim_buf_get_name(0), api.nvim_get_current_buf())
    if not root_dir then
      root_dir = util.path.dirname(api.nvim_buf_get_name(0))
    end
    if not root_dir then
      root_dir = vim.fn.getcwd()
    end
    root_dir = string.gsub(root_dir, "\\", "/")
    api.nvim_command(
      string.format(
        "autocmd %s lua require'ionide'.manager.try_add_wrapper()",
        "BufReadPost " .. root_dir .. "/*"
      )
    )
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local buf_dir = api.nvim_buf_get_name(bufnr)
      if buf_dir:sub(1, root_dir:len()) == root_dir then
        M.Manager.try_add_wrapper(bufnr)
      end
    end
  end

  local reload = false
  if M.Manager then
    for _, client in ipairs(M.Manager.clients()) do
      client.stop(true)
    end
    reload = true
    M.Manager = nil
  end

  local make_config = function(_root_dir)
    local new_config = vim.tbl_deep_extend("keep", vim.empty_dict(), config)
    new_config = vim.tbl_deep_extend("keep", new_config, default_config)
    new_config.capabilities = new_config.capabilities or lsp.protocol.make_client_capabilities()
    new_config.capabilities = vim.tbl_deep_extend("keep", new_config.capabilities, {
      workspace = {
        configuration = true,
      },
    })
    if config.on_new_config then
      pcall(config.on_new_config, new_config, _root_dir)
    end
    new_config.on_init = util.add_hook_after(new_config.on_init, function(client, _result)
      function client.workspace_did_change_configuration(settings)
        if not settings then
          return
        end
        if vim.tbl_isempty(settings) then
          settings = { [vim.type_idx] = vim.types.dictionary }
        end
        local settingsInspected = vim.inspect(settings)
        vim.notify("Settings being sent to LSP server are: " .. settingsInspected)
        return client.notify("workspace/didChangeConfiguration", {
          settings = settings,
        })
      end

      if not vim.tbl_isempty(new_config.settings) then
        local settingsInspected = vim.inspect(new_config.settings)
        vim.notify("Settings being sent to LSP server are: " .. settingsInspected)
        client.workspace_did_change_configuration(new_config.settings)
      end
    end)
    new_config._on_attach = new_config.on_attach
    new_config.on_attach = vim.schedule_wrap(function(client, bufnr)
      if bufnr == api.nvim_get_current_buf() then
        M._setup_buffer(client.id, bufnr)
      else
        api.nvim_command(
          string.format(
            "autocmd BufEnter <buffer=%d> ++once lua require'ionide'._setup_buffer(%d,%d)",
            bufnr,
            client.id,
            bufnr
          )
        )
      end
    end)
    new_config.root_dir = _root_dir
    return new_config
  end

  local manager = util.server_per_root_dir_manager(function(_root_dir) return make_config(_root_dir) end)
  function manager.try_add(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    if api.nvim_buf_get_option(bufnr, 'buftype') == 'nofile' then
      return
    end
    local root_dir = get_root_dir(api.nvim_buf_get_name(bufnr), bufnr)
    local id = manager.add(root_dir)
    if id then
      lsp.buf_attach_client(bufnr, id)
    end
  end

  function manager.try_add_wrapper(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local buftype = api.nvim_buf_get_option(bufnr, 'filetype')
    if buftype == 'fsharp' then
      manager.try_add(bufnr)
      return
    end
  end

  M.Manager = manager
  M.MakeConfig = make_config
  if reload and not (config.autostart == false) then
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      manager.try_add_wrapper(bufnr)
    end
  else
    autostart_if_needed(M, config)
  end
end

-- partially adopted from neovim/nvim-lspconfig, see lspconfig.LICENSE.md
function M._setup_buffer(client_id, bufnr)
  local client = lsp.get_client_by_id(client_id)
  if not client then
    return
  end
  if client.config._on_attach then
    client.config._on_attach(client, bufnr)
  end
end

function M.setup(config)
  if lspconfig_is_present then
    return delegate_to_lspconfig(config)
  end
  return create_manager(config)
end

function M.status()
  if lspconfig_is_present then
    print("* LSP server: handled by nvim-lspconfig")
  elseif M.Manager ~= nil then
    if next(M.Manager.clients()) == nil then
      print("* LSP server: not started")
    else
      print("* LSP server: started")
    end
  else
    print("* LSP server: not initialized")
  end
end

--     " FSI keymaps
--     if g:fsharp#fsi_keymap == "vscode"
--         if has('nvim')
--             let g:fsharp#fsi_keymap_send   = "<M-cr>"
--             let g:fsharp#fsi_keymap_toggle = "<M-@>"
--         else
--             let g:fsharp#fsi_keymap_send   = "<esc><cr>"
--             let g:fsharp#fsi_keymap_toggle = "<esc>@"
--         endif
--     elseif g:fsharp#fsi_keymap == "vim-fsharp"
--         let g:fsharp#fsi_keymap_send   = "<leader>i"
--         let g:fsharp#fsi_keymap_toggle = "<leader>e"
--     elseif g:fsharp#fsi_keymap == "custom"
--         let g:fsharp#fsi_keymap = "none"
--         if !exists('g:fsharp#fsi_keymap_send')
--             echoerr "g:fsharp#fsi_keymap_send is not set"
--         elseif !exists('g:fsharp#fsi_keymap_toggle')
--             echoerr "g:fsharp#fsi_keymap_toggle is not set"
--         else
--             let g:fsharp#fsi_keymap = "custom"
--         endif
--     endif
--

if vim.fn.has('nvim') then
  if M.FsiKeymap == "vscode" then
    M.FsiKeymapSend = "<M-cr>"
    M.FsiKeymapToggle = "<M-@>"
  elseif M.FsiKeymap == "vim-fsharp" then
    M.FsiKeymapSend   = "<leader>i"
    M.FsiKeymapToggle = "<leader>e"
  elseif M.FsiKeymap == "custom" then
    M.FsiKeymap = "none"
    if not M.FsiKeymapSend then
      vim.cmd.echoerr("FsiKeymapSend not set. good luck with that I dont have a nice way to change it yet. sorry. ")
    elseif not M.FsiKeymapToggle then
      vim.cmd.echoerr("FsiKeymapToggle not set. good luck with that I dont have a nice way to change it yet. sorry. ")
    else
      M.FsiKeymap = "custom"
    end
  end
else
  vim.notify("I'm sorry I don't support this, try ionide/ionide-vim instead")
end


-- " " FSI integration
--"
--" let s:fsi_buffer = -1
--" let s:fsi_job    = -1
--" let s:fsi_width  = 0
--" let s:fsi_height = 0
local fsiBuffer = -1
local fsiJob = -1
local fsiWidth = 0
local fsiHeight = 0
--"
--" function! s:win_gotoid_safe(winid)
--"     function! s:vimReturnFocus(window)
--"         call win_gotoid(a:window)
--"         redraw!
--"     endfunction
--"     if has('nvim')
--"         call win_gotoid(a:winid)
--"     else
--"         call timer_start(1, { -> s:vimReturnFocus(a:winid) })
--"     endif
--" endfunction
local function vimReturnFocus(window)
  vim.fn.win_gotoid(window)
  vim.cmd.redraw("!")
end

local function winGoToIdSafe(id)

  if vim.cmd.has('nvim') then
    vim.fn.win_gotoid(id)
  else
    vim.fn.timer_start(1, function() vimReturnFocus(id) end, {})
  end
end

--"
--" function! s:get_fsi_command()
--"     let cmd = g:fsharp#fsi_command
--"     for prm in g:fsharp#fsi_extra_parameters
--"         let cmd = cmd . " " . prm
--"     endfor
--"     return cmd
--" endfunction

local function getFsiCommand()
  local cmd = M.FsiCommand or "dotnet fsi"
  local ep = M.FSIExtraParameters or {}
  for _, x in pairs(ep) do
    cmd = cmd .. ' ' .. x
  end
  return cmd

end

--" function! fsharp#openFsi(returnFocus)
function M.OpenFsi(returnFocus)
  local isNeovim = vim.fn.has('nvim')

  --"     if bufwinid(s:fsi_buffer) <= 0
  if vim.fn.bufwinid(fsiBuffer) <= 0 then

    --"         let fsi_command = s:get_fsi_command()
    local cmd = getFsiCommand()
    --"         if exists('*termopen') || exists('*term_start')
    if vim.fn.exists('*termopen') == true or vim.fn.exists('*term_start') then
      --"             let current_win = win_getid()
      local currentWin = vim.fn.win_getid()
      --"             execute g:fsharp#fsi_window_command
      vim.fn.execute(M.FsiWindowCommand or 'botright 10new')
      --"             if s:fsi_width  > 0 | execute 'vertical resize' s:fsi_width | endif
      if fsiWidth > 0 then vim.fn.execute('vertical resize ' .. fsiWidth) end
      --"             if s:fsi_height > 0 | execute 'resize' s:fsi_height | endif

      if fsiHeight > 0 then vim.fn.execute('resize ' .. fsiHeight) end
      --"             " if window is closed but FSI is still alive then reuse it
      --"             if s:fsi_buffer >= 0 && bufexists(str2nr(s:fsi_buffer))
      if fsiBuffer >= 0 and vim.fn.bufexists(fsiBuffer) then
        --"                 exec 'b' s:fsi_buffer
        vim.fn.cmd('b' .. tostring(fsiBuffer))
        --"                 normal G

        vim.cmd("normal G")
        --"                 if !has('nvim') && mode() == 'n' | execute "normal A" | endif

        if not isNeovim and vim.api.nvim_get_mode()[1] == 'n' then
          vim.cmd("normal A")
        end
        --"                 if a:returnFocus | call s:win_gotoid_safe(current_win) | endif
        if returnFocus then winGoToIdSafe(currentWin) end
        --"             " open FSI: Neovim
        --"             elseif has('nvim')
      elseif isNeovim then
        --"                 let s:fsi_job = termopen(fsi_command)
        fsiJob = vim.fn.termopen(cmd) or 0
        --"                 if s:fsi_job > 0
        if fsiJob > 0 then
          --"                     let s:fsi_buffer = bufnr("%")
          fsiBuffer = vim.fn.bufnr(tonumber(vim.fn.expand("%")))
          --"                 else
        else
          --"                     close
          vim.cmd.close()
          --"                     echom "[FSAC] Failed to open FSI."
          vim.notify("Ionide failed to open FSI")
          --"                     return -1
          return -1
          --"                 endif
        end
        --"             " open FSI: Vim
        --"             else
      else
        --"                 let options = {
        local options = {
          term_name = "F# Interactive",
          curwin = 1,
          term_finish = "close"
        }
        --"                 \ "term_name": "F# Interactive",

        --"                 \ "curwin": 1,

        --"                 \ "term_finish": "close"

        --"                 \ }

        --"                 let s:fsi_buffer = term_start(fsi_command, options)
        fsiBuffer = vim.fn("term_start(" .. M.FsiCommand .. ", " .. vim.inspect(options) .. ")")
        --"                 if s:fsi_buffer != 0
        if fsiBuffer ~= 0 then
          --"                     if exists('*term_setkill') | call term_setkill(s:fsi_buffer, "term") | endif
          if vim.fn.exists('*term_setkill') == true then vim.fn("term_setkill(" .. fsiBuffer .. [["term"]]) end
          --"                     let s:fsi_job = term_getjob(s:fsi_buffer)
          fsiJob = vim.cmd.term_getjob(fsiBuffer)
          --"                 else
        else
          --"                     close

          vim.cmd.close()
          --"                     echom "[FSAC] Failed to open FSI."

          vim.notify("Ionide failed to open FSI")
          --"                     return -1
          return -1
          --"                 endif

        end
        --"             endif

      end
      --"             setlocal bufhidden=hide

      vim.opt_local.bufhidden = "hide"
      --"             normal G

      vim.cmd("normal G")
      --"             if a:returnFocus | call s:win_gotoid_safe(current_win) | endif
      if returnFocus then winGoToIdSafe(currentWin) end
      --"             return s:fsi_buffer
      return fsiBuffer
      --"         else
    else
      --"             echom "[FSAC] Your (neo)vim does not support terminal".
      vim.notify("Ionide - Your neovim doesn't support terminal.")
      --"             return 0
      return 0
      --"         endif
    end
    --"     endif
  end
  return fsiBuffer
  --" endfunction
end

--"
--" function! fsharp#toggleFsi()
--"     let fsiWindowId = bufwinid(s:fsi_buffer)
--"     if fsiWindowId > 0
--"         let current_win = win_getid()
--"         call win_gotoid(fsiWindowId)
--"         let s:fsi_width = winwidth('%')
--"         let s:fsi_height = winheight('%')
--"         close
--"         call win_gotoid(current_win)
--"     else
--"         call fsharp#openFsi(0)
--"     endif
--" endfunction
function M.ToggleFsi()
  local w = vim.fn.bufwinid(fsiBuffer)
  if w > 0 then
    local curWin = vim.fn.win_getid()
    M.winGoToId(w)
    fsiWidth = vim.fn.winwidth(tonumber(vim.fn.expand('%')) or 0)
    fsiHeight = vim.fn.winheight(tonumber(vim.fn.expand('%')) or 0)
    vim.cmd.close()
    vim.fn.win_gotoid(curWin)
  else
    M.OpenFsi()
  end
end

M.GetVisualSelection = function()
  local line_start, column_start = unpack(vim.fn.getpos("'<"))
  local line_end, column_end = unpack(vim.fn.getpos("'>"))
  local lines = vim.fn.getline(line_start, line_end)
  if #lines == 0 then
    return {}
  end
  lines[-1] = string.sub(lines[-1], 1, column_end - (vim.opt.selection == 'inclusive' and 1 or 2))
  lines[1] = string.sub(lines[1], column_start)
  return lines
end
--"
--" function! fsharp#quitFsi()
--"     if s:fsi_buffer >= 0 && bufexists(str2nr(s:fsi_buffer))
--"         if has('nvim')
--"             let winid = bufwinid(s:fsi_buffer)
--"             if winid > 0 | execute "close " . winid | endif
--"             call jobstop(s:fsi_job)
--"         else
--"             call job_stop(s:fsi_job, "term")
--"         endif
--"         let s:fsi_buffer = -1
--"         let s:fsi_job = -1
--"     endif
--" endfunction
function M.QuitFsi()
  if vim.api.nvim_buf_is_valid(fsiBuffer) then
    local is_neovim = vim.api.nvim_eval("has('nvim')")
    if is_neovim then
      local winid = vim.api.nvim_call_function("bufwinid", { fsiBuffer })
      if winid > 0 then
        vim.api.nvim_win_close(winid, true)
      end
    end
    vim.api.nvim_call_function("jobstop", { fsiJob })
    fsiBuffer = -1
    fsiJob = -1
  end
end

--" function! fsharp#resetFsi()
--"     call fsharp#quitFsi()
--"     return fsharp#openFsi(1)
--" endfunction
--"
function M.ResetFsi()
  M.QuitFsi()
  M.OpenFsi(true)
end

--" function! fsharp#sendFsi(text)
--"     if fsharp#openFsi(!g:fsharp#fsi_focus_on_send) > 0
--"         " Neovim
--"         if has('nvim')
--"             call chansend(s:fsi_job, a:text . "\n" . ";;". "\n")
--"         " Vim 8
--"         else
--"             call term_sendkeys(s:fsi_buffer, a:text . "\<cr>" . ";;" . "\<cr>")
--"             call term_wait(s:fsi_buffer)
--"         endif
--"     endif
--" endfunction
-- "

function M.SendFsi(text)
  if M.OpenFsi(M.FsiFocusOnSend or true) > 0 then
    if vim.fn.has('nvim') then
      vim.fn.chansend(fsiJob, text .. "\n" .. ";;" .. "\n")
    else
      vim.api.nvim_call_function("term_sendkeys", { fsiBuffer, text .. "\\<cr>" .. ";;" .. "\\<cr>" })
      vim.api.nvim_call_function("term_wait", { fsiBuffer })
    end
  end
end

function M.GetCompleteBuffer()
  return vim.fn.join(vim.fn.getline(1, tonumber(vim.fn.expand('$'))), "\n")
end

function M.SendSelectionToFsi()
  local lines = M.GetVisualSelection()
  vim.fn.exec('normal' .. vim.fn.len(lines) .. 'j')
  local text = vim.fn.join(lines, "\n")
  return M.SendFsi(text)
end

function M.SendLineToFsi()
  local text = vim.api.nvim_get_current_line()
  vim.fn.exec 'normal j'
  return M.SendFsi(text)
end

function M.SendAllToFsi()
  local text = M.GetCompleteBuffer()
  return M.SendFsi(text)
end

-- if g:fsharp#fsi_keymap != "none"
--     execute "vnoremap <silent>" g:fsharp#fsi_keymap_send ":call fsharp#sendSelectionToFsi()<cr><esc>"
--     execute "nnoremap <silent>" g:fsharp#fsi_keymap_send ":call fsharp#sendLineToFsi()<cr>"
--     execute "nnoremap <silent>" g:fsharp#fsi_keymap_toggle ":call fsharp#toggleFsi()<cr>"
--     execute "tnoremap <silent>" g:fsharp#fsi_keymap_toggle "<C-\\><C-n>:call fsharp#toggleFsi()<cr>"
-- endif
function M.SetKeymaps()
  if not M.FsiKeymap == "none" then
    vim.keymap.set({ "v" }, M.FsiKeymapSend, M.SendSelectionToFsi, { silent = true })
    vim.keymap.set({ "n" }, M.FsiKeymapSend, M.SendLineToFsi, { silent = true })
    vim.keymap.set({ "n" }, M.FsiKeymapToggle, M.ToggleFsi, { silent = true })
    vim.keymap.set({ "t" }, M.FsiKeymapToggle, M.ToggleFsi, { silent = true })
  end

end

return M
