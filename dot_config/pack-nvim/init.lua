vim.loader.enable()

-- ============================================================================
-- UTILS
-- ============================================================================

local set = vim.keymap.set
_G.set = vim.keymap.set

vim.opt.rtp:prepend(vim.fn.expand("~/Code/neovim/plugins/bu"))
vim.opt.rtp:prepend(vim.fn.expand("~/Code/lulu-code/integrations/btty.nvim"))

-- ============================================================================
-- OPTIONS (from options.lua, excluding Snacks-specific stuff)
-- ============================================================================

vim.g.mapleader = " "

vim.o.autoindent = true
vim.o.autoread = true
vim.o.confirm = true
vim.o.ignorecase = true
vim.o.backspace = "indent,eol,start"
vim.o.cmdheight = 0
vim.o.cursorline = true
vim.o.directory = "~/.vim-tmp/,~/.tmp/,~/tmp/,/var/tmp/,/tmp"
vim.o.mouse = "nvi"
vim.o.mousemodel = "popup_setpos"
vim.o.hlsearch = true
vim.o.expandtab = true
vim.o.incsearch = true
vim.o.laststatus = 3
vim.o.linebreak = true
vim.o.modelines = 1
vim.o.backup = false
vim.o.swapfile = false
vim.o.writebackup = true
vim.o.joinspaces = false
vim.o.showmode = false
vim.o.wrap = false
vim.o.number = true
vim.o.numberwidth = 5
vim.o.ruler = false
vim.o.scrolloff = 5
vim.o.shiftwidth = 2
vim.o.shiftround = true
vim.o.showcmd = true
vim.o.signcolumn = "yes:2"
vim.o.smartcase = true
vim.o.smarttab = true
vim.o.softtabstop = 2
vim.o.tabstop = 2
vim.o.textwidth = 0
vim.o.tags = "./TAGS,TAGS"
vim.o.wildignore = "*.swp,.git,.svn,*.log,*.gif,*.jpeg,*.jpg,*.png,*.pdf,tmp/**,.DS_STORE,.DS_Store"
vim.opt.shortmess:append("Icq")
vim.o.termguicolors = true
vim.o.exrc = true

vim.o.pumheight = 10
vim.o.conceallevel = 2
vim.o.grepformat = "%f:%l:%c:%m"
vim.o.grepprg = "rg --vimgrep"
vim.o.splitkeep = "screen"
vim.o.splitright = true
vim.o.conceallevel = 2
vim.o.smoothscroll = true
-- vim.o.winborder = "rounded"

-- Folding
vim.o.foldenable = true
vim.opt.foldlevel = 99
vim.o.foldmethod = "expr"

vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }

vim.opt.foldtext = ""
vim.opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}

vim.opt.timeoutlen = 500
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.updatetime = 200

vim.o.foldcolumn = "1"

-- Yank highlight
vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.hl.hl_op({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Completion options
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- disable python 2
vim.g.loaded_python_provider = 0

-- ============================================================================
-- PLUGIN HELPERS
-- ============================================================================

---@return boolean
local function is_mac()
  return vim.fn.has("mac") == 1
end

_G.is_mac = is_mac

---@return boolean
local function is_windows()
  return vim.fn.has("win32") == 1
end

_G.is_windows = is_windows

---@return boolean
local function is_vscode()
  return vim.g.vscode ~= nil
end

_G.is_vscode = is_vscode

---Returns a function that inverts the result of the given function
---@param fn fun():boolean
---@return fun():boolean
local function invert(fn)
  return function()
    return not fn()
  end
end

_G.invert = invert

---Checks if a plugin is active (was loaded via vim.pack.add)
---@param name string Plugin name
---@return boolean
local function is_active(name)
  local info = vim.pack.get({ name })
  return info[1] ~= nil and info[1].active
end

_G.is_active = is_active

-- URL helpers for shorter plugin specs
---@param repo string Repository in "user/repo" format
---@return string
local function gh(repo)
  return "https://github.com/" .. repo
end

_G.gh = gh

---@param repo string Repository in "user/repo" format
---@return string
local function gl(repo)
  return "https://gitlab.com/" .. repo
end

_G.gl = gl

---@param repo string Repository in "user/repo" format
---@return string
local function cb(repo)
  return "https://codeberg.org/" .. repo
end

_G.cb = cb

vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(event)
    if
      event.data.spec
      and event.data.spec.name == "fff.nvim"
      and event.data.active
      and (event.data.kind == "install" or event.data.kind == "update")
    then
      require("fff.download").download_or_build_binary()
    end
  end,
})

vim.api.nvim_create_user_command("Qa", "qa", {})
vim.api.nvim_create_user_command("Wq", "wq", {})
vim.api.nvim_create_user_command("W", "w", {})

-- ============================================================================
-- PACK COMMANDS (similar to Lazy.nvim)
-- ============================================================================

-- Get list of plugin names for completion
local function get_plugin_names()
  return vim
    .iter(vim.pack.get())
    :map(function(plugin)
      return plugin.spec.name
    end)
    :totable()
end

-- :Pack update [plugin]
vim.api.nvim_create_user_command("Pack", function(opts)
  local args = opts.fargs
  local subcmd = args[1]

  if subcmd == "update" then
    vim.api.nvim_cmd({
      cmd = "packupdate",
      args = vim.list_slice(args, 2),
      bang = opts.bang,
    }, {})
  elseif subcmd == "info" or subcmd == "get" then
    local plugin_name = args[2]
    local info = vim.pack.get(plugin_name and { plugin_name } or nil, { info = true })

    -- Display info in a scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = { "# Pack Info", "" }

    for _, plugin in ipairs(info) do
      table.insert(lines, "## " .. plugin.spec.name)
      table.insert(lines, "  Path: " .. plugin.path)
      table.insert(lines, "  Active: " .. tostring(plugin.active))
      table.insert(lines, "  Rev: " .. plugin.rev)
      if plugin.branches then
        table.insert(lines, "  Branches: " .. table.concat(plugin.branches, ", "))
      end
      if plugin.tags then
        table.insert(lines, "  Tags: " .. #plugin.tags .. " available")
      end
      table.insert(lines, "")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].modifiable = false

    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, buf)
  else
    vim.notify("Unknown Pack subcommand: " .. (subcmd or ""), vim.log.levels.ERROR)
    vim.notify("Available: update [plugin], info [plugin]", vim.log.levels.INFO)
  end
end, {
  nargs = "*",
  bang = true,
  desc = "Manage vim.pack plugins",
  complete = function(arg_lead, cmd_line, _)
    local args = vim.split(cmd_line, "%s+")
    local subcmd = args[2]

    -- Complete subcommands
    if #args == 2 then
      return vim.tbl_filter(function(cmd)
        return cmd:find(arg_lead) == 1
      end, { "update", "info", "get" })
    end

    -- Complete plugin names for subcommands
    if #args == 3 and (subcmd == "update" or subcmd == "info" or subcmd == "get") then
      local plugin_names = get_plugin_names()
      return vim.tbl_filter(function(name)
        return name:find(arg_lead) == 1
      end, plugin_names)
    end

    return {}
  end,
})

-- ============================================================================
-- BASIC KEYMAPPINGS (from mappings.lua)
-- ============================================================================

set("n", { "j", "<Down>" }, 'v:count || mode(1)[0:1] == "no" ? "j" : "gj"', { expr = true, desc = "Move down a line" })
set("n", { "k", "<Up>" }, 'v:count || mode(1)[0:1] == "no" ? "k" : "gk"', { expr = true, desc = "Move up a line" })

set("x", { "<" }, "<gv", { desc = "Decrease indent" })
set("x", { ">", "<Tab>" }, ">gv", { desc = "Increase indent" })

set("n", "<ESC>", "<CMD>noh<CR>", { desc = "Clear search highlight" })
set("n", { "<C-s>", "<D-s>" }, vim.cmd.write, { desc = "Save file" })
set("x", "<F2>", '"*y', { desc = "Copy to system clipboard" })
set("n", "<F3>", [[<cmd>let @+ = fnamemodify(expand('%'), ':.')<CR>]], { desc = "Copy relative file path" })
set("n", "<A-BS>", "db", { desc = "Delete previous word" })
set("i", "<A-BS>", "<C-W>", { desc = "Delete previous word" })

set("n", "Q", vim.cmd.quit, { desc = "Quit window" })
set("n", "]t", vim.cmd.tabnext, { desc = "Next tab" })
set("n", "[t", vim.cmd.tabprevious, { desc = "Previous tab" })
set({ "n", "o", "x" }, "gl", "$", { desc = "End of line" })

-- NOTE: This is just the exact copy of the builtin mappings.
-- https://github.com/neovim/neovim/blob/ea878f456a8b15381ce215b6e53781b0a061c5f4/runtime/lua/vim/_core/defaults.lua#L462-L477I
set({ "n", "x", "o" }, "<CR>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) then
    vim.treesitter.select("parent", vim.v.count1)
  else
    vim.lsp.buf.selection_range(vim.v.count1)
  end
end, { desc = "Select parent (outer) node" })

set({ "x", "o" }, "<BS>", function()
  if vim.treesitter.get_parser(nil, nil, { error = false }) then
    vim.treesitter.select("child", vim.v.count1)
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

-- ============================================================================
-- DIAGNOSTIC CONFIGURATION
-- ============================================================================

vim.diagnostic.config({
  virtual_text = false,
  underline = {
    severity = vim.diagnostic.severity.ERROR,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ✘",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
  float = {
    show_header = false,
    source = true,
  },
  update_in_insert = false,
})

-- LSP Keymaps
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

set("n", "gd", function()
  vim.lsp.buf.definition()
end, { silent = true, desc = "Go to definition" })

set("n", "grr", function()
  vim.lsp.buf.references()
end, { desc = "Go to references" })

set("n", "gri", function()
  vim.lsp.buf.implementation()
end, { desc = "Go to implementation" })

set("n", "gry", function()
  vim.lsp.buf.type_definition()
end, { desc = "Go to type definition" })

set({ "n", "x" }, "gra", function()
  require("tiny-code-action").code_action()
end, { desc = "Select a code action" })

set("n", "K", hover, { silent = true, desc = "Hover" })
