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

M.register_callback = function(fn)
  if M.backend ~= 'nvim' then
    return -1
  end
  local rnd = os.time()
  callbacks[rnd] = fn
  return rnd
end

M.resolve_callback = function(key, arg)
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
  local sn = str:gsub("(%u%l+|%l+)(%u)", "%l%1_%l%2")
  if sn == str then return str:lower() end
  return sn
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

M.call = function(method, params, callback_key)
  local handler = function(err, result, ctx, config)
    if result ~= nil then
      M.resolve_callback(callback_key, {
        result = result,
        err = err,
        client_id = ctx.client_id,
        bufnr = ctx.bufnr
      })
    end
  end
  lsp.buf_request(0, method, params, handler)
end

M.notify = function(method, params)
  lsp.buf_notify(0, method, params)
end

Workspace = {}


M.signature = function(filePath, line, character, cont)
  return call('fsharp/signature', M.TextDocumentPositionParams(filePath, line, character),
    cont)
end

M.signatureData = function(filePath, line, character, cont)
  return call('fsharp/signatureData', M.TextDocumentPositionParams(filePath, line, character)
    , cont)
end

M.lineLens = function(projectPath, cont)
  return call('fsharp/lineLens', M.ProjectParms(projectPath), cont)
end

M.compilerLocation = function(cont)
  return call('fsharp/compilerLocation', {}, cont)
end

M.compile = function(projectPath, cont)
  return call('fsharp/compile', M.ProjectParms(projectPath), cont)
end

M.workspacePeek = function(directory, depth, excludedDirs, cont)
  return call('fsharp/workspacePeek', M.WorkspacePeekRequest(directory, depth, excludedDirs),
    cont)
end

M.workspaceLoad = function(files, cont)
  return call('fsharp/workspaceLoad', M.WorkspaceLoadParms(files), cont)
end

M.project = function(projectPath, cont)
  return call('fsharp/project', M.ProjectParms(projectPath), cont)
end

M.fsdn = function(signature, cont)
  return call('fsharp/fsdn', M.FsdnRequest(signature), cont)
end

M.f1Help = function(filePath, line, character, cont)
  return call('fsharp/f1Help', M.TextDocumentPositionParams(filePath, line, character), cont)
end

M.documentation = function(filePath, line, character, cont)
  return call('fsharp/documentation', M.TextDocumentPositionParams(filePath, line, character)
    , cont)
end

M.documentationSymbol = function(xmlSig, assembly, cont)
  return call('fsharp/documentationSymbol', M.DocumentationForSymbolRequest(xmlSig, assembly)
    , cont)
end

local function getServerConfig()
  local config = {}
  local camels = {
    { key = "AutomaticWorkspaceInit", default = 1 },
    { key = "WorkspaceModePeekDeepLevel", default = 4 },
    { key = "ExcludeProjectDirectories", default = {} },
    { key = "keywordsAutocomplete", default = 1 },
    { key = "ExternalAutocomplete", default = 0 },
    { key = "Linter", default = 1 },
    { key = "UnionCaseStubGeneration", default = 1 },
    { key = "UnionCaseStubGenerationBody" },
    { key = "RecordStubGeneration", default = 1 },
    { key = "RecordStubGenerationBody" },
    { key = "InterfaceStubGeneration", default = 1 },
    { key = "InterfaceStubGenerationObjectIdentifier", default = "this" },
    { key = "InterfaceStubGenerationMethodBody" },
    { key = "UnusedOpensAnalyzer", default = 1 },
    { key = "UnusedDeclarationsAnalyzer", default = 1 },
    { key = "SimplifyNameAnalyzer", default = 1 },
    { key = "ResolveNamespaces", default = 1 },
    { key = "EnableReferenceCodeLens", default = 1 },
    { key = "EnableAnalyzers", default = 1 },
    { key = "AnalyzersPath" },
    { key = "DisableInMemoryProjectReferences", default = 0 },
    { key = "LineLens", default = { enabled = "always", prefix = "//" } },
    { key = "UseSdkScripts", default = 1 },
    { key = "dotNetRoot" },
    { key = "fsiExtraParameters", default = {} },
  }
  local keys = buildConfigKeys(camels)
  for _, key in ipairs(keys) do
    if not vim.g[key.snake] then
      vim.g[key.snake] = key.default or ""
    end
    if vim.g[key.snake] then
      config[key.camel] = M[key.snake]
    elseif vim.g[key.camel] then
      config[key.camel] = M[key.camel]
    elseif key.default and M.use_recommended_server_config then
      vim.g[key.snake] = key.default
      config[key.camel] = key.default
    end
  end

  return config
end

M.updateServerConfig = function()
  local fsharp = getServerConfig()
  local settings = { settings = { FSharp = fsharp } }
  M.notify("workspace/didChangeConfiguration", settings)
end

local addThenSort = function(value, tbl)
  table.insert(tbl, value)
  table.sort(tbl)
  -- print("after sorting table, it now looks like this : " .. vim.inspect(tbl))
  return tbl
end


--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentHighlight
M.handle_documentHighlight = function(err, result, ctx, _)
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

M.handle_notifyWorkspace = function(payload)
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
      M.updateServerConfig()

      -- print("[Ionide] after calling updateServerconfig, workspace looks like:   " .. vim.inspect(Workspace))
      print("[Ionide] Workspace loaded (" .. #Workspace .. " project(s))")
    end
  end
end

local handlers = { ['fsharp/notifyWorkspace'] = "handle_notifyWorkspace",
  ['textDocument/documentHighlight'] = "handle_documentHighlight" }

local function getHandlers()
  return handlers
end

M.create_handlers = function()
  local h = getHandlers()
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
  M.handlers = r
  return r
end

local function load(arg)
  M.workspaceLoad(arg, nil)
end

M.loadProject = function(...)
  local prjs = {}
  for _, proj in ipairs({ ... }) do
    table.insert(prjs, util.fnamemodify(proj, ':p'))
  end
  load(prjs)
end

M.showLoadedProjects = function()
  for _, proj in ipairs(Workspace) do
    print("- " .. proj)
  end
end

M.reloadProjects = function()
  if #Workspace > 0 then
    M.workspaceLoad(Workspace, nil)
  else
    print("[Ionide] Workspace is empty")
  end
end

M.OnFSProjSave = function()
  if vim.bo.ft == "fsharp_project" and M.automatic_reload_workspace and M.automatic_reload_workspace == 1 then
    M.reloadProjects()
  end
end

M.loadConfig = function()

  M.fsautocomplete_command = { "fsautocomplete", "--adaptive-lsp-server-enabled", "-v" }
  M.use_recommended_server_config = 1
  -- getServerConfig()
  M.automatic_workspace_init = 1
  M.automatic_reload_workspace = 1
  M.show_signature_on_cursor_move = 1
  M.fsi_command = "dotnet fsi"
  M.fsi_keymap = "vscode"
  M.fsi_window_command = "botright 10new"
  M.fsi_focus_on_send = 0
  M.backend = "nvim"
  M.lsp_auto_setup = 0
  M.lsp_recommended_colorscheme = 1
  M.lsp_codelens = 1
  M.fsi_vscode_keymaps = 1
  M.statusline = "Ionide"
  M.autocmd_events = { "BufEnter", "BufWritePost", "CursorHold", "CursorHoldI", "InsertEnter",
    "InsertLeave" }
  M.fsi_keymap_send = "<M-cr>"
  M.fsi_keymap_toggle = "<M-@>"

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


M.showSignature = function()
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

  M.signature(vim.fn.expand("%:p"), vim.cmd.line('.') - 1, vim.cmd.col('.') - 1,
    cbShowSignature)
end

-- function! fsharp#OnCursorMove()
--     if g:fsharp#show_signature_on_cursor_move
--         call fsharp#showSignature()
--     endif
-- endfunction
--
M.OnCursorMove = function()
  if M.show_signature_on_cursor_move then
    M.showSignature()
  end
end


M.registerAutocmds = function()
  --     if g:fsharp#backend == 'nvim' && g:fsharp#lsp_codelens
  if M.backend == 'nvim' and (M.lsp_codelens == true or M.lsp_codelens == 1) then
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

M.initialize = function()
  print 'Ionide Initializing'
  print 'Ionide calling updateServerConfig...'
  M.updateServerConfig()
  print 'Ionide calling registerAutocmds...'
  M.registerAutocmds()
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
  local auto_init = M.automatic_workspace_init
  local result = {
    name = "ionide",
    cmd = { 'fsautocomplete', '--adaptive-lsp-server-enabled', '-v' },
    cmd_env = { DOTNET_ROLL_FORWARD = "LatestMajor" },
    filetypes = { "fsharp" },
    autostart = true,
    handlers = M.create_handlers(),
    init_options = { AutomaticWorkspaceInit = (auto_init == 1) },
    on_init = M.initialize,
    settings = M.loadConfig(),
    root_dir = local_root_dir,
    -- root_dir = util.root_pattern("*.sln"),
  }
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
          vim.bo[bufnr].syntax.set = 'xml'
        end
      end,
    },
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

M.get_visual_selection = function()
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

local get_complete_buffer = function()
  return vim.fn.join(vim.fn.getline(1, tonumber(vim.fn.expand('$'))), "\n")
end

function M.sendSelectionToFsi()
  local lines = M.get_visual_selection()
  vim.fn.exec('normal' .. vim.fn.len(lines) .. 'j')
  local text = vim.fn.join(lines, "\n")
  return M.sendFsi(text)
end

function M.sendLineToFsi()
  local text = vim.api.nvim_get_current_line()
  vim.fn.exec 'normal j'
  return M.sendFsi(text)
end

function M.sendAllToFsi()
  local text = get_complete_buffer()
  return M.sendFsi(text)
end

return M
