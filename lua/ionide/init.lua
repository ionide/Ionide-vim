local vim = vim
local validate = vim.validate
local api = vim.api
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

M.RegisterCallback = function(fn)
  if M.backend ~= 'nvim' then
    return -1
  end
  local rnd = os.time()
  callbacks[rnd] = fn
  return rnd
end

M.ResolveCallback = function(key, arg)
  if M.backend ~= 'nvim' then
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
  local handler = function(err, result, ctx, config)
    if result ~= nil then
      M.ResolveCallback(callback_key, {
        result = result,
        err = err,
        client_id = ctx.client_id,
        bufnr = ctx.bufnr
      })
    end
  end
  lsp.buf_request(0, method, params, handler)
end

M.Notify = function(method, params)
  lsp.buf_notify(0, method, params)
end

Workspace = {}


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
    --false
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
    { key = "DotNetRoot", default = "" },
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
      config[key.camel] = key.default or ""
    end
    if vim.g[key.snake] then
      config[key.camel] = vim.g[key.snake]
    elseif vim.g[key.camel] then
      config[key.camel] = vim.g[key.snake]
    elseif key.default and M.use_recommended_server_config then
      vim.g[key.camel] = key.default or ""
      vim.g[key.snake] = key.default or ""
      config[key.camel] = key.default or ""
    end
  end
  -- vim.notify("ionide config is " .. vim.inspect(config))
  return config
end

M.UpdateServerConfig = function()
  local fsharp = getServerConfig()
  local settings = { settings = { FSharp = fsharp } }
  M.Notify("workspace/didChangeConfiguration", settings)
end

local addThenSort = function(value, tbl)
  table.insert(tbl, value)
  table.sort(tbl)
  -- print("after sorting table, it now looks like this : " .. vim.inspect(tbl))
  return tbl
end


--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
M.HandleDocumentHighlight = function(err, result, ctx, _)
  if not result then
    -- print("no result for doc highlight ")
    return
  end
  if err then
    print("doc highlight had an error. ")
    if err.code == protocol.ErrorCodes.InternalError then
      print("doc highlight error code is: " .. err.code)
      print("doc highlight error message is: " .. err.message)
      return
    end
  end
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    print("doc highlight cannot happen without lsp, and for some reason i can't find lsp with id of: " .. client_id)
    return
  end
  local u = require("vim.lsp.util")
  print("now calling vim.lps.util.buf_highlight_references...")
  u.buf_highlight_references(ctx.bufnr, result, client.offset_encoding)
end

M.HandleNotifyWorkspace = function(payload)
  local content = vim.json.decode(payload.content)
  if content then
    if content.Kind == 'projectLoading' then
      print("[Ionide] Loading " .. content.Data.Project)
      -- print("[Ionide] now calling AddOrUpdateThenSort on table  " .. vim.inspect(Workspace))
      Workspace = addThenSort(content.Data.Project, Workspace)

      -- print("after attempting to reassign table value it looks like this : " .. vim.inspect(Workspace))
    elseif content.Kind == 'workspaceLoad' and content.Data.Status == 'finished' then
      -- print("[Ionide] calling updateServerConfig ... ")

      -- print("[Ionide] before calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
      M.UpdateServerConfig()

      -- print("[Ionide] after calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
      print("[Ionide] Workspace loaded (" .. #Workspace .. " project(s))")
    end
  end
end

local handlers = { ['fsharp/notifyWorkspace'] = "HandleNotifyWorkspace",
  ['textDocument/documentHighlight'] = "HandleDocumentHighlight" }

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

      if params == nil or not (method == ctx.method) then return end
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
  for _, proj in ipairs(Workspace) do
    print("- " .. proj)
  end
end

M.ReloadProjects = function()
  if #Workspace > 0 then
    M.WorkspaceLoad(Workspace, nil)
  else
    print("[Ionide] Workspace is empty")
  end
end

M.OnFSProjSave = function()
  if vim.bo.ft == "fsharp_project" and M.AutomaticReloadWorkspace and M.AutomaticReloadWorkspace == true then
    M.reloadProjects()
  end
end

M.LoadConfig = function()

  local generalConfigs = {

    FsAutocompleteCommand = { "fsautocomplete", "--adaptive-lsp-server-enabled", "-v" },
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
    M.showSignature()
  end
end


M.RegisterAutocmds = function()
  --     if g:fsharp#backend == 'nvim' && g:fsharp#lsp_codelens
  if M.backend == 'nvim' and (M.LspCodelens == true or M.LspCodelens == 1) then
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
  local config = M.loadConfig()
  local result = {
    name = "ionide",
    cmd = { 'fsautocomplete', '--adaptive-lsp-server-enabled', '-v' },
    cmd_env = { DOTNET_ROLL_FORWARD = "LatestMajor" },
    filetypes = { "fsharp" },
    autostart = true,
    handlers = M.CreateHandlers(),
    init_options = { AutomaticWorkspaceInit = M.AutomaticWorkspaceInit },
    on_init = M.initialize,
    settings = { FSharp = config },
    root_dir = local_root_dir,
    -- root_dir = util.root_pattern("*.sln"),
  }
  vim.notify("ionide defalut settings are : " .. vim.inspect(result))
  return result
end

M.manager = nil

local function autostart_if_needed(m, config)
  local auto_setup = (M.lsp_auto_setup == 1)
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
            https://github.com/ionide/Ionide-vim
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
          vim.cmd("set syntax= xml")
        end
      end,
    },
  })

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.fsproj",
  desc = "FSharp Auto refresh on project save",
  group = vim.api.nvim_create_augroup("FSharpLCFsProj"),
  callback = function() M.OnFSProjSave() end
})
--augroup FSharpLC_fsproj
-- autocmd! BufWritePost *.fsproj call fsharp#OnFSProjSave()
--augroup END

if not vim.g.filetype_fs then
  vim.g['filetype_fs'] = 'fsharp'
end
if not vim.g.filetype_fs == 'fsharp' then
  vim.g['filetype_fs'] = 'fsharp'
end
if vim.b.did_fsharp_ftplugin and vim.b.did_fsharp_ftplugin == 1 then
  return
end

vim.b.did_fsharp_ftplugin = 1

local cpo_save = vim.o.cpo
vim.o.cpo = ''

-- enable syntax based folding
vim.b.fdm = 'syntax'

-- comment settings
vim.b.formatoptions = 'croql'
vim.b.commentstring = '(*%s*)'
vim.b.comments = [[s0:*\ -,m0:*\ \ ,ex0:*),s1:(*,mb:*,ex:*),:\/\/\/,:\/\/]]

-- make ftplugin undo-able
vim.b.undo_ftplugin = 'setl fo< cms< com< fdm<'

local function prompt(msg)
  local height = vim.o.cmdheight
  if height < 2 then
    vim.o.cmdheight = 2
  end
  print(msg)
  vim.o.cmdheight = height
end

vim.o.cpo = cpo_save

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

  function M.autostart()
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
        M.manager.try_add_wrapper(bufnr)
      end
    end
  end

  local reload = false
  if M.manager then
    for _, client in ipairs(M.manager.clients()) do
      client.stop(true)
    end
    reload = true
    M.manager = nil
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

  M.manager = manager
  M.make_config = make_config
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
  elseif M.manager ~= nil then
    if next(M.manager.clients()) == nil then
      print("* LSP server: not started")
    else
      print("* LSP server: started")
    end
  else
    print("* LSP server: not initialized")
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

M.GetCompleteBuffer = function()
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

return M
