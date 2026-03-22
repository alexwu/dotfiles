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

return M
