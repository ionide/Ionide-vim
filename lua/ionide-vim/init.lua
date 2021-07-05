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

local lspconfig_is_present = false
local lspconfig = try_require('lspconfig')
if lspconfig ~= nil then
  lspconfig_is_present = true
end

local util = try_require('lspconfig/util')
if util == nil then
  util = require('ionide-vim/util')
end

local setup_in_progress = false
local client = nil
local setup_done = false
local manager = nil

local function setup(cmd, auto_init)
  if lspconfig_is_present then
    require("lspconfig")["fsautocomplete"].autostart()
  elseif setup_in_progress or setup_done then return end
  setup_in_progress = true

  local get_root_dir = util.root_pattern("*.sln", "*.fsproj", ".git")

  local make_config = function(root_dir)
    local config = util.default_config
    config.name = "FSAC"
    config.cmd = cmd
    config.root_dir = root_dir
    config.init_options = { AutomaticWorkspaceInit = (auto_init == 1) }
    config.on_init = function(_client, _result)
      setup_done = true
      print("[FSAC] workspace loaded")
    end
    return config
  end

  if manager then
    for _, client in ipairs(manager.clients()) do
      client.stop(true)
    end
    manager = nil
  end
  
  manager = util.server_per_root_dir_manager(function(_root_dir) return make_config(_root_dir) end)
  function manager.try_add(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_option(bufnr, "filetype") == "nofile" then
      return
    end
    local root_dir = get_root_dir(api.nvim_buf_get_name(bufnr), bufnr)
    local id = manager.add(root_dir)
    if id then
      lsp.buf_attach_client(bufnr, id)
    end
  end
  function manager.try_add_wrapper(bufnr)
    local buftype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    if buftype == 'fsharp' then
      manager.try_add(bufnr)
      return
    end
  end

  local root_dir = get_root_dir(api.nvim_buf_get_name(0), api.nvim_get_current_buf())
  if not root_dir then
    local curbuf = api.nvim_get_current_buf()
    root_dir = path.dirname(curbuf)
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local buf_dir = api.nvim_buf_get_name(bufnr)
    if buf_dir:sub(1, root_dir:len()) == root_dir then
      manager.try_add_wrapper(bufnr)
    end
  end
  
  setup_in_progress = false
end

local function status()
  if lspconfig_is_present then
    print("* LSP server: handled by nvim-lspconfig")
  elseif setup_done then
    print("* LSP server: started")
  else
    print("* LSP server: not started")
  end
end

local function call(method, params, callback_key)
  local handler = function(err, method, result, client_id, bufnr, config)
    if result ~= nil then
      fn['fsharp#resolve_callback'](callback_key, { result = result })
    end
  end
  return lsp.buf_request(0, method, params, handler)
end

local function notify(method, params)
  return lsp.buf_notify(0, method, params)
end

return {
  notify = notify,
  call = call,
  setup = setup,
  status = status,
}
