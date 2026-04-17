local M = {}

local function indent_lines(lines, offset)
  return vim.tbl_map(function(val)
    return offset .. val
  end, lines)
end

---@param cmd string|string[]|fun(...): any
---@return string cmd_str
---@return string cmd_is_executable
local function format_cmd(cmd)
  if cmd == nil then
    return "cmd not defined", "NA"
  end
  if type(cmd) == "function" then
    return "<function>", "NA"
  end
  if type(cmd) == "table" then
    local cmd_str = table.concat(cmd, " ")
    if vim.fn.executable(cmd[1]) == 1 then
      return cmd_str, "true"
    end
    return cmd_str, "executable not found"
  end
  return tostring(cmd), "NA"
end

---@param client vim.lsp.Client
---@return string[]
local function make_client_info(client)
  local attached = {}
  for bufnr, _ in pairs(client.attached_buffers or {}) do
    attached[#attached + 1] = tostring(bufnr)
  end
  table.sort(attached)

  local cmd_str, cmd_is_executable = format_cmd(client.config.cmd)
  local root_dir = client.config.root_dir or client.root_dir or "Running in single file mode."

  local lines = {
    "",
    ("Client: %s (id: %d, bufnr: [%s])"):format(client.name, client.id, table.concat(attached, ", ")),
  }

  local info_lines = {
    "filetypes:         " .. table.concat(client.config.filetypes or {}, ", "),
    "root directory:    " .. tostring(root_dir),
    "cmd:               " .. cmd_str,
    "cmd is executable: " .. cmd_is_executable,
  }

  vim.list_extend(lines, indent_lines(info_lines, "\t"))
  return lines
end

---@param filetype string
---@return { name: string, enabled: boolean }[]
local function get_configured_servers(filetype)
  local seen = {}
  local servers = {}
  for _, config in ipairs(vim.lsp.get_configs({ filetype = filetype }) or {}) do
    local name = config.name
    if name and not seen[name] then
      seen[name] = true
      servers[#servers + 1] = {
        name = name,
        enabled = vim.lsp.is_enabled(name),
      }
    end
  end
  table.sort(servers, function(a, b)
    return a.name < b.name
  end)
  return servers
end

local function setup_syntax(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd([[
      syn keyword String true
      syn keyword Error false
      syn match LspInfoFiletypeList /\<filetypes\?:\s*\zs.*\ze/ contains=LspInfoFiletype
      syn match LspInfoFiletype /\k\+/ contained
      syn match LspInfoTitle /^\s*\%(Client\|Config\):\s*\zs\S\+\ze/
      syn match LspInfoEnabled /\[enabled\]/
      syn match LspInfoDisabled /\[disabled\]/

      hi def link LspInfoEnabled DiagnosticOk
      hi def link LspInfoDisabled Comment

      hi def link LspInfoTitle Title
      hi def link LspInfoList Identifier
      hi def link LspInfoFiletype Type
    ]])
  end)
end

function M.show()
  local original_bufnr = vim.api.nvim_get_current_buf()
  local buf_clients = vim.lsp.get_clients({ bufnr = original_bufnr })
  local all_clients = vim.lsp.get_clients()
  local buffer_filetype = vim.bo[original_bufnr].filetype

  local buf_client_ids = {}
  for _, client in ipairs(buf_clients) do
    buf_client_ids[client.id] = true
  end

  local other_active_clients = {}
  for _, client in ipairs(all_clients) do
    if not buf_client_ids[client.id] then
      other_active_clients[#other_active_clients + 1] = client
    end
  end

  local lines = {
    "Press q or <Esc> to close this window.",
    "",
    "Language client log: " .. vim.lsp.log.get_filename(),
    "Detected filetype:   " .. buffer_filetype,
    "",
    ("%d client(s) attached to this buffer:"):format(#buf_clients),
  }

  for _, client in ipairs(buf_clients) do
    vim.list_extend(lines, make_client_info(client))
  end

  if not vim.tbl_isempty(other_active_clients) then
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("%d active client(s) not attached to this buffer:"):format(#other_active_clients)
    for _, client in ipairs(other_active_clients) do
      vim.list_extend(lines, make_client_info(client))
    end
  end

  local configured = get_configured_servers(buffer_filetype)
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("Configured servers for %s (%d):"):format(buffer_filetype, #configured)
  for _, server in ipairs(configured) do
    local status = server.enabled and "[enabled]" or "[disabled]"
    lines[#lines + 1] = ("\t%-24s %s"):format(server.name, status)
  end

  lines = indent_lines(lines, " ")

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = "lspinfo"
  vim.bo[bufnr].bufhidden = "wipe"
  setup_syntax(bufnr)

  Snacks.win({
    buf = bufnr,
    width = 0.8,
    height = 0.7,
    border = "rounded",
    title = " LSP Info ",
    title_pos = "center",
    wo = {
      wrap = true,
      breakindent = true,
      breakindentopt = "shift:25",
      signcolumn = "no",
      number = false,
      relativenumber = false,
      cursorline = false,
    },
    keys = {
      q = "close",
      ["<Esc>"] = "close",
    },
  })
end

return M
