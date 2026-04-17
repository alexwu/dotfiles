local M = {}

---@param modes string|string[]
---@param mappings string|string[]
---@param callback string|function
---@param opts? table
function M.set(modes, mappings, callback, opts)
  opts = opts or {}
  if type(mappings) == "string" then
    mappings = { mappings }
  end

  for _, mapping in ipairs(mappings) do
    vim.keymap.set(modes, mapping, callback, opts)
  end
end

_G.set = M.set

local set = M.set

-- j/k with gj/gk smart movement
set("n", { "j", "<Down>" }, 'v:count || mode(1)[0:1] == "no" ? "j" : "gj"', { expr = true, desc = "Move down a line" })
set("n", { "k", "<Up>" }, 'v:count || mode(1)[0:1] == "no" ? "k" : "gk"', { expr = true, desc = "Move up a line" })

-- Indent keymaps
set("x", { "<" }, "<gv", { desc = "Decrease indent" })
set("x", { ">", "<Tab>" }, ">gv", { desc = "Increase indent" })

-- Basic keymaps
set("n", "<ESC>", "<CMD>noh<CR>", { desc = "Clear search highlight" })
set("n", { "<C-s>", "<D-s>" }, vim.cmd.write, { desc = "Save file" })
set("x", "<F2>", '"*y', { desc = "Copy to system clipboard" })
set("n", "<F3>", [[<cmd>let @+ = fnamemodify(expand('%'), ':.')<CR>]], { desc = "Copy relative file path" })
set("n", "<A-BS>", "db", { desc = "Delete previous word" })
set("i", "<A-BS>", "<C-W>", { desc = "Delete previous word" })

set("n", "Q", vim.cmd.quit, { desc = "Quit window" })
set("n", "]t", vim.cmd.tabnext, { desc = "Next tab" })
set("n", "[t", vim.cmd.tabprevious, { desc = "Previous tab" })

-- NOTE: This is just the exact copy of the builtin mappings.
-- https://github.com/neovim/neovim/blob/ea878f456a8b15381ce215b6e53781b0a061c5f4/runtime/lua/vim/_core/defaults.lua#L462-L477I
set({ "n", "x", "o" }, "<CR>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) then
    require("vim.treesitter._select").select_parent(vim.v.count1)
  else
    vim.lsp.buf.selection_range(vim.v.count1)
  end
end, { desc = "Select parent (outer) node" })

set({ "x", "o" }, "<BS>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) then
    require("vim.treesitter._select").select_child(vim.v.count1)
  else
    vim.lsp.buf.selection_range(-vim.v.count1)
  end
end, { desc = "Select child (inner) node" })

-- Scroll half page
local function scroll_half_page(dir)
  local line_count = vim.api.nvim_buf_line_count(0)
  local height = vim.api.nvim_win_get_height(0)
  local half_height = math.floor(height / 2)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  if dir == "down" then
    local next_pos = math.min(line_count, row + half_height)
    vim.api.nvim_win_set_cursor(0, { next_pos, col })
  else
    local next_pos = math.max(1, row - half_height)
    vim.api.nvim_win_set_cursor(0, { next_pos, col })
  end
end

set({ "n", "v" }, "<C-d>", function()
  scroll_half_page("down")
end, { desc = "Scroll down half page" })

set({ "n", "v" }, "<C-u>", function()
  scroll_half_page("up")
end, { desc = "Scroll up half page" })

-- Typo commands
vim.api.nvim_create_user_command("Qa", "qa", {})
vim.api.nvim_create_user_command("Wq", "wq", {})
vim.api.nvim_create_user_command("W", "w", {})

-- LSP mappings (always mapped regardless of plugin load state)
local function hover()
  local filetype = vim.filetype.match({ buf = 0 })
  if vim.tbl_contains({ "vim", "help" }, filetype) then
    vim.cmd("h " .. vim.fn.expand("<cword>"))
  elseif filetype == "man" then
    vim.cmd("Man " .. vim.fn.expand("<cword>"))
  else
    local ok, pretty_hover = pcall(require, "pretty_hover")
    if ok then
      pretty_hover.hover()
    else
      vim.lsp.buf.hover()
    end
  end
end

set("i", "<C-y>", function()
  if not vim.lsp.inline_completion.get() then
    return "<C-y>"
  end
end, { expr = true, desc = "Accept the current inline completion" })

set("n", "gd", function()
  vim.lsp.buf.definition()
end, { silent = true, desc = "Go to definition" })

set("n", "grr", function()
  vim.lsp.buf.references()
end, { desc = "Go to references" })

set("n", "gri", function()
  vim.lsp.buf.implementation()
end, { desc = "Go to implementation" })

set("n", "grt", function()
  vim.lsp.buf.type_definition()
end, { desc = "Go to type definition" })

set("n", "grx", function()
  vim.lsp.codelens.run()
end, { desc = "Run code lens" })

set("n", "K", hover, { silent = true, desc = "Hover" })

set({ "n", "x" }, "gra", function()
  require("tiny-code-action").code_action()
end, { desc = "Select a code action" })

return M
