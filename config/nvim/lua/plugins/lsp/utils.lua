local M = {}
local util = require("vim.lsp.util")

function M.default_on_attach(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end

  local signs = {
    Error = "✘ ",
    Warning = " ",
    Hint = " ",
    Information = " "
  }

  for type, icon in pairs(signs) do
    local hl = "LspDiagnosticsSign" .. type
    vim.fn.sign_define(hl, {text = icon, texthl = hl, numhl = ""})
  end

  vim.lsp.handlers["textDocument/publishDiagnostics"] =
    vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics,
                 {virtual_text = true, underline = true, signs = true})
  vim.lsp.handlers["textDocument/hover"] =
    vim.lsp
      .with(vim.lsp.handlers.hover, {border = "rounded", focusable = false})

  local original_set_virtual_text = vim.lsp.diagnostic.set_virtual_text
  local set_virtual_text_custom = function(diagnostics, bufnr, client_id,
                                           sign_ns, opts)
    opts = opts or {}
    -- show all messages that are Warning and above (Warning, Error)
    opts.severity_limit = "Error"
    original_set_virtual_text(diagnostics, bufnr, client_id, sign_ns, opts)
  end

  vim.lsp.diagnostic.set_virtual_text = set_virtual_text_custom

  local opts = {noremap = false, silent = true}
  buf_set_keymap("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  buf_set_keymap("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>",
                 opts)
  buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap("n", "L",
                 "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics({border = 'rounded', focusable = false})<CR>",
                 opts)
  buf_set_keymap("n", "<RightMouse>",
                 "<LeftMouse><cmd>lua vim.lsp.diagnostic.show_line_diagnostics({border = 'rounded', focusable = false})<CR>",
                 opts)
  buf_set_keymap("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
  buf_set_keymap("n", "<space>q",
                 "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)

  -- Set some keybinds conditional on server capabilities
  --[[ if client.resolved_capabilities.document_formatting then
    buf_set_keymap("n", "<leader>f", "<cmd>lua vim.lsp.buf.formatting()<CR>",
                   opts)
  elseif client.resolved_capabilities.document_range_formatting then
    buf_set_keymap("n", "<leader>f",
                   "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
  end ]]

  require"lsp_signature".on_attach({
    bind = true,
    handler_opts = {border = "single"}
  })
  -- vim.cmd [[ autocmd CursorHold * lua vim.lsp.diagnostic.show_line_diagnostics({border = 'rounded', focusable = false}) ]]
  -- vim.cmd [[ autocmd CursorHold * lua require('plenary.async').run(_G.async_show_diagnostics, {border = 'rounded', focusable = false}) ]]
  -- vim.cmd [[ autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb() ]]
end

local to_position = function(position, bufnr)
  vim.validate {position = {position, "t"}}

  return {position.line, util._get_line_byte_from_position(bufnr, position)}
end

_G.async_show_diagnostics = require("plenary.async").wrap(
                              vim.lsp.diagnostic.show_line_diagnostics, 1)

-- @private
--- Helper function to ierate through diagnostic lines and return a position
---
---@return table {row, col}
-- local function _iter_diagnostic_lines_pos(opts, line_diagnostics)
--   opts = opts or {}

--   local win_id = opts.win_id or vim.api.nvim_get_current_win()
--   local bufnr = vim.api.nvim_win_get_buf(win_id)

--   if line_diagnostics == nil or vim.tbl_isempty(line_diagnostics) then
--     return false
--   end

--   local iter_diagnostic = line_diagnostics[1]
--   return to_position(iter_diagnostic.range.start, bufnr)
-- end

--- Open a floating window with the diagnostics from {line_nr}
---
--- The floating window can be customized with the following highlight groups:
--- <pre>
--- LspDiagnosticsFloatingError
--- LspDiagnosticsFloatingWarning
--- LspDiagnosticsFloatingInformation
--- LspDiagnosticsFloatingHint
--- </pre>
---@param opts table Configuration table
---     - show_header (boolean, default true): Show "Diagnostics:" header.
---     - Plus all the opts for |vim.lsp.diagnostic.get_line_diagnostics()|
---          and |vim.lsp.util.open_floating_preview()| can be used here.
---@param bufnr number The buffer number
---@param line_nr number The line number
---@param client_id number|nil the client id
---@return table {popup_bufnr, win_id}
-- function module.show_line_diagnostics(opts, bufnr, line_nr, client_id)
--   opts = opts or {}

--   local show_header = if_nil(opts.show_header, true)

--   bufnr = bufnr or 0
--   line_nr = line_nr or (vim.api.nvim_win_get_cursor(0)[1] - 1)

--   local lines = {}
--   local highlights = {}
--   if show_header then
--     table.insert(lines, "Diagnostics:")
--     table.insert(highlights, {0, "Bold"})
--   end

--   local line_diagnostics = M.get_line_diagnostics(bufnr, line_nr, opts,
--                                                   client_id)
--   if vim.tbl_isempty(line_diagnostics) then return end

--   for i, diagnostic in ipairs(line_diagnostics) do
--     local prefix = string.format("%d. ", i)
--     local hiname = M._get_floating_severity_highlight_name(diagnostic.severity)
--     assert(hiname, "unknown severity: " .. tostring(diagnostic.severity))

--     local message_lines = vim.split(diagnostic.message, "\n", true)
--     table.insert(lines, prefix .. message_lines[1])
--     table.insert(highlights, {#prefix, hiname})
--     for j = 2, #message_lines do
--       table.insert(lines, string.rep(" ", #prefix) .. message_lines[j])
--       table.insert(highlights, {0, hiname})
--     end
--   end

--   opts.focus_id = "line_diagnostics"
--   local popup_bufnr, winnr =
--     util.open_floating_preview(lines, "plaintext", opts)
--   for i, hi in ipairs(highlights) do
--     local prefixlen, hiname = unpack(hi)
--     -- Start highlight after the prefix
--     api.nvim_buf_add_highlight(popup_bufnr, -1, hiname, i - 1, prefixlen, -1)
--   end

--   return popup_bufnr, winnr
-- end

return M;
