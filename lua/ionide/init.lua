local vim = vim
local validate = vim.validate
local api = vim.api
local lsp = vim.lsp
local uv = vim.loop
local fn = vim.fn
local tbl_extend = vim.tbl_extend

function try_require(...)
  local status, lib = pcall(require, ...)
  if(status) then return lib end
  return nil
end

local lspconfig_is_present = true
local util = try_require('lspconfig.util')
if util == nil then
  lspconfig_is_present = false
  util = require('ionide.util')
end

local M = {}

local function create_handlers()
  local handlers = fn['fsharp#get_handlers']()
  local result = {}
  for method, func_name in pairs(handlers) do
    local handler = function(err, params, ctx, _config)
      if params == nil or not (method == ctx.method) then return end
      fn[func_name](params)
    end
    result[method] = handler
  end
  M.handlers = result
  return result
end

local function get_default_config()
  local result = {}
  fn['fsharp#loadConfig']()

  local auto_init = vim.g['fsharp#automatic_workspace_init']
  result.name = "ionide"
  result.cmd = vim.g['fsharp#fsautocomplete_command']
  result.cmd_env = { DOTNET_ROLL_FORWARD = "LatestMajor" }
  result.root_dir = util.root_pattern("*.sln", "*.fsproj", ".git")
  result.filetypes = {"fsharp"}
  result.autostart = true
  result.handlers = create_handlers()
  result.init_options = { AutomaticWorkspaceInit = (auto_init == 1) }
  result.on_init = function() fn['fsharp#initialize']() end

  return result
end

M.manager = nil

local function autostart_if_needed(m, config)
  local auto_setup = (vim.g['fsharp#lsp_auto_setup'] == 1)
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

-- partially adopted from neovim/nvim-lspconfig, see lspconfig.LICENSE.md
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

function M.call(method, params, callback_key)
  local handler = function(err, result, ctx, config)
    if result ~= nil then
      fn['fsharp#resolve_callback'](callback_key, {
        result = result,
        err = err,
        client_id = ctx.client_id,
        bufnr = ctx.bufnr
      })
    end
  end
  lsp.buf_request(0, method, params, handler)
end

function M.notify(method, params)
  lsp.buf_notify(0, method, params)
end

return M
