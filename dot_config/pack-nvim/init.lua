-- pack_init.lua - Minimal Neovim config using vim.pack builtin plugin manager
-- Requires Neovim 0.11+ nightly

-- ============================================================================
-- MONKEY PATCH: Fix vim.system returning nil stdout/stderr
-- ============================================================================
-- HACK: Neovim dev builds have a bug where vim.system returns nil for
-- stdout/stderr instead of empty strings, breaking vim.pack.update()

-- do
--   local original_system = vim.system
--   ---@diagnostic disable-next-line: duplicate-set-field
--   vim.system = function(cmd, opts, on_exit)
--     -- Normalize the callback to ensure stdout/stderr are strings
--     local function normalize_result(result)
--       result.stdout = result.stdout or ""
--       result.stderr = result.stderr or ""
--       return result
--     end
--
--     if on_exit then
--       -- Async version with callback - wrap the callback
--       local wrapped_exit = function(result)
--         on_exit(normalize_result(result))
--       end
--       return original_system(cmd, opts, wrapped_exit)
--     else
--       -- Sync version - wrap :wait()
--       local obj = original_system(cmd, opts)
--       local original_wait = obj.wait
--       obj.wait = function(self, timeout)
--         local result = original_wait(self, timeout)
--         return normalize_result(result)
--       end
--       return obj
--     end
--   end
-- end

-- ============================================================================
-- MINIMAL UTILS (just the set helper)
-- ============================================================================

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

local set = M.set

-- ============================================================================
-- OPTIONS (from options.lua, excluding Snacks-specific stuff)
-- ============================================================================

vim.g.mapleader = " "

vim.o.autoindent = true
vim.o.ch = 2
vim.o.confirm = true
vim.o.ignorecase = true
vim.o.backspace = "indent,eol,start"
vim.o.cmdheight = 1
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
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Completion options
vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- disable python 2
vim.g.loaded_python_provider = 0

-- ============================================================================
-- PLUGIN INSTALLATION (vim.pack.add)
-- ============================================================================

---@return boolean
local function is_mac()
  return vim.fn.has("mac") == 1
end

---@return boolean
local function is_windows()
  return vim.fn.has("win32") == 1
end

---@return boolean
local function is_vscode()
  return vim.g.vscode ~= nil
end

---Returns a function that inverts the result of the given function
---@param fn fun():boolean
---@return fun():boolean
local function invert(fn)
  return function()
    return not fn()
  end
end

---Checks if a plugin is active (was loaded via vim.pack.add)
---@param name string Plugin name
---@return boolean
local function is_active(name)
  local info = vim.pack.get({ name })
  return info[1] ~= nil and info[1].active
end

-- URL helpers for shorter plugin specs
---@param repo string Repository in "user/repo" format
---@return string
local function gh(repo)
  return "https://github.com/" .. repo
end

---@param repo string Repository in "user/repo" format
---@return string
local function gl(repo)
  return "https://gitlab.com/" .. repo
end

---@param repo string Repository in "user/repo" format
---@return string
local function cb(repo)
  return "https://codeberg.org/" .. repo
end

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

---@class PackSpec
---@field src string Plugin source (URL or local path)
---@field name? string Optional plugin name (derived from src if omitted)
---@field version? string|vim.VersionRange Git tag, branch, or version range
---@field cond? boolean|fun():boolean Condition to load plugin (defaults to true)

---@type PackSpec[]
local plugins = {
  -- Treesitter (main branch - breaking changes!)
  { src = gh("nvim-treesitter/nvim-treesitter") },
  { src = gh("nvim-treesitter/nvim-treesitter-textobjects"), version = "main" },
  { src = gh("MeanderingProgrammer/treesitter-modules.nvim") },
  { src = gh("nvim-treesitter/nvim-treesitter-context") },
  -- Formatting
  { src = gh("stevearc/conform.nvim") },
  -- LSP
  { src = gh("neovim/nvim-lspconfig") },
  { src = gh("williamboman/mason.nvim") },
  { src = gh("williamboman/mason-lspconfig.nvim") },
  { src = gh("rachartier/tiny-inline-diagnostic.nvim"), cond = invert(is_vscode) },
  { src = gh("smjonas/inc-rename.nvim") },
  -- Mini plugins
  { src = gh("nvim-mini/mini.surround") },
  { src = gh("nvim-mini/mini.splitjoin") },
  { src = gh("nvim-mini/mini.ai") },
  { src = gh("nvim-mini/mini.icons") },
  { src = gh("nvim-mini/mini.diff") },
  { src = gh("nvim-mini/mini.align") },
  -- Movement
  { src = gh("chrisgrieser/nvim-spider") },
  { src = gh("folke/flash.nvim") },
  -- Search/Replace
  { src = gh("MagicDuck/grug-far.nvim") },
  -- Colorscheme
  { src = gh("rktjmp/lush.nvim") },
  { src = gh("alexwu/nvim-snazzy") },
  -- Snacks
  { src = gh("folke/snacks.nvim"), cond = invert(is_vscode) },
  -- Auto-detect indentation
  { src = gh("NMAC427/guess-indent.nvim") },
  -- Fast fuzzy file finder
  { src = gh("dmtrKovalenko/fff.nvim"), cond = invert(is_vscode) },
  -- Fuzzy matcher (builtin matchfuzzy)
  -- { src = gh("asmodeus812/nvim-fuzzymatch") },
  -- File explorer
  { src = gh("stevearc/oil.nvim"), cond = invert(is_vscode) },
  -- Completion
  { src = gh("saghen/blink.cmp"), version = vim.version.range("*") },
  { src = gh("rafamadriz/friendly-snippets") },
  -- UI
  { src = gh("folke/which-key.nvim") },
  -- Other
  { src = gh("tpope/vim-repeat") },
  { src = gh("sindrets/diffview.nvim"), cond = invert(is_vscode) },
  { src = gh("mrjones2014/smart-splits.nvim") },
  { src = gh("monaqa/dial.nvim") },
  { src = gh("vim-test/vim-test") },
  { src = gh("saghen/blink.indent"), cond = invert(is_vscode) },
  { src = gh("saghen/blink.pairs"), version = vim.version.range("*") },
  { src = gh("stevearc/overseer.nvim"), cond = invert(is_vscode) },
  { src = gh("chrisgrieser/nvim-tinygit"), cond = invert(is_vscode) },
  { src = gh("folke/ts-comments.nvim") },
}

---Determines if a plugin should be loaded based on its cond field
---@param spec PackSpec
---@return boolean
local function should_load(spec)
  if spec.cond == nil then
    return true
  elseif type(spec.cond) == "function" then
    return spec.cond()
  else
    return spec.cond
  end
end

---Strips the cond field from a spec (not needed by vim.pack)
---@param spec PackSpec
---@return table
local function strip_cond(spec)
  local result = vim.tbl_extend("force", {}, spec)
  result.cond = nil
  return result
end

vim.pack.add(vim.tbl_map(strip_cond, vim.tbl_filter(should_load, plugins)))

-- Download/build fff.nvim binary on plugin changes
-- Apply colorscheme
vim.cmd.colorscheme("snazzy")

-- ============================================================================
-- BLINK.CMP CONFIGURATION
-- ============================================================================

require("blink.cmp").setup({
  fuzzy = {
    prebuilt_binaries = {
      download = true,
    },
  },
  keymap = {
    preset = "super-tab",
    ["<CR>"] = { "accept", "fallback" },
    ["<C-e>"] = { "cancel", "fallback" },
    ["<S-Tab>"] = { "select_prev", "fallback" },
    ["<Tab>"] = { "select_next", "fallback" },
  },
  completion = {
    accept = {
      auto_brackets = { enabled = true },
    },
    list = {
      selection = {
        preselect = false,
        auto_insert = false,
      },
    },
    menu = {
      border = "rounded",
      draw = {
        columns = { { "label" }, { "kind_icon", "kind", "source_name", gap = 1 } },
      },
    },
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 0,
      window = {
        border = "rounded",
      },
    },
  },
  appearance = {
    use_nvim_cmp_as_default = false,
    nerd_font_variant = "mono",
  },
  signature = {
    enabled = true,
    window = {
      border = "rounded",
    },
  },
  sources = {
    default = { "lsp", "path", "snippets", "buffer" },
  },
})

-- ============================================================================
-- WHICH-KEY CONFIGURATION
-- ============================================================================

require("which-key").setup({
  preset = "modern",
  spec = {
    {
      mode = { "n", "v" },
      { "[", group = "prev" },
      { "]", group = "next" },
    },
    {
      mode = { "n" },
      { "<Space>", group = "leader" },
      { "<leader>f", group = "picker" },
    },
  },
  delay = function(ctx)
    return ctx.plugin and 0 or 200
  end,
  triggers = {
    { "<auto>", mode = "nixsotc" },
    { "<leader>", mode = { "n", "v" } },
    { "<space>", mode = { "n" } },
  },
  icons = {
    rules = false,
  },
  layout = {
    height = { min = 4, max = 25 },
    width = { min = 20, max = 50 },
    spacing = 3,
    align = "center",
  },
})

set("n", "g?", function()
  require("which-key").show({ global = true })
end, { desc = "Keymaps (which-key)" })

set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer keymaps (which-key)" })

vim.api.nvim_create_user_command("Qa", "qa", {})
vim.api.nvim_create_user_command("Wq", "wq", {})
vim.api.nvim_create_user_command("W", "w", {})

-- ============================================================================
-- SNACKS.NVIM CONFIGURATION
-- ============================================================================

if is_active("snacks.nvim") then
  require("snacks").setup({
    input = {},
    gitbrowse = {},
    statuscolumn = {},
    picker = {
      enabled = true,
      win = {
        input = {
          keys = {
            ["<Esc>"] = { "close", mode = { "n", "i" } },
            ["<c-u>"] = { "clear_input", mode = { "i" } },
          },
        },
      },
      actions = {
        clear_input = function(picker)
          picker.input:set("")
        end,
      },
    },
  })

  -- Set statuscolumn to use Snacks
  vim.o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]

  -- Snacks keymaps
  set("n", { "<c-`>" }, function()
    Snacks.terminal.toggle()
  end, { desc = "Toggle Terminal (bottom)" })

  set("n", { "<c-/>", "<c-_>" }, function()
    Snacks.terminal()
  end, { desc = "Toggle Terminal (floating)" })

  -- Snacks picker keymaps
  set("n", "<leader><space>", function()
    Snacks.picker.smart()
  end, { desc = "Files (smart)" })

  set("n", "<leader>/", function()
    Snacks.picker.grep()
  end, { desc = "Grep" })

  set("n", "<leader>gs", function()
    Snacks.picker.git_status()
  end, { desc = "Files (git status)" })

  set("n", "<leader>fb", function()
    Snacks.picker.buffers()
  end, { desc = "Buffers" })

  set("n", "<leader>f/", function()
    Snacks.picker.search_history()
  end, { desc = "Search history" })

  set("n", "<leader>fc", function()
    Snacks.picker.command_history()
  end, { desc = "Command history" })

  set("n", "<leader>fh", function()
    Snacks.picker.help()
  end, { desc = "Help pages" })

  set("n", "<leader>fH", function()
    Snacks.picker.highlights()
  end, { desc = "Highlights" })

  set("n", "<leader>fii", function()
    Snacks.picker.icons()
  end, { desc = "Icons" })

  set("n", "<leader>fj", function()
    Snacks.picker.jumps()
  end, { desc = "Jumps" })

  set("n", "<leader>fn", function()
    Snacks.picker.notifications()
  end, { desc = "Notifications" })

  set("n", "<leader>fk", function()
    Snacks.picker.keymaps({ global = true, plugs = true, ["local"] = true })
  end, { desc = "Keymaps" })
end

-- ============================================================================
-- GUESS-INDENT CONFIGURATION
-- ============================================================================

require("guess-indent").setup({})

-- ============================================================================
-- NVIM-FUZZYMATCH CONFIGURATION
-- ============================================================================

-- require("fuzzy").setup({})

-- Fuzzy file finder keymap
-- set("n", "<leader>ff", function()
--   require("fuzzy.sources.files").files():open()
-- end, { desc = "Find files (fuzzy)" })

-- ============================================================================
-- FFF.NVIM CONFIGURATION
-- ============================================================================

if is_active("fff.nvim") then
  vim.g.fff = {
    lazy_sync = true, -- start syncing only when the picker is open
    debug = {
      enabled = false,
      show_scores = false,
    },
  }

  set("n", "<leader>ff", function()
    require("fff").find_files()
  end, { desc = "Files" })

  -- ============================================================================
  -- PICK COMMAND (unified picker interface)
  -- ============================================================================

  -- Custom pickers registry (easily extensible!)
  local custom_pickers = {
    {
      name = "files",
      callback = function()
        require("fff").find_files()
      end,
    },
    -- Add more custom pickers here:
    -- { name = "my_custom", callback = function() ... end },
  }

  -- Get list of available pickers
  local function get_picker_names()
    local pickers = {}

    -- Add custom pickers
    for _, picker in ipairs(custom_pickers) do
      table.insert(pickers, picker.name)
    end

    -- Add Snacks pickers
    if Snacks and Snacks.picker and Snacks.picker.sources then
      for name, _ in pairs(Snacks.picker.sources) do
        table.insert(pickers, name)
      end
    end

    return pickers
  end

  vim.api.nvim_create_user_command("Pick", function(opts)
    local picker_name = opts.args

    -- Default to files if no argument
    if picker_name == "" then
      picker_name = "files"
    end

    -- Check custom pickers first
    for _, picker in ipairs(custom_pickers) do
      if picker.name == picker_name then
        picker.callback()
        return
      end
    end

    -- Fall back to Snacks picker
    if Snacks and Snacks.picker then
      Snacks.picker(picker_name)
    else
      vim.notify("Picker not found: " .. picker_name, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Open picker",
    complete = function(arg_lead, _, _)
      local pickers = get_picker_names()
      return vim.tbl_filter(function(name)
        return name:find(arg_lead, 1, true) == 1
      end, pickers)
    end,
  })
end

-- ============================================================================
-- PACK COMMANDS (similar to Lazy.nvim)
-- ============================================================================

-- Get list of plugin names for completion
local function get_plugin_names()
  local plugins = vim.pack.get()
  local names = {}
  for _, plugin in ipairs(plugins) do
    table.insert(names, plugin.spec.name)
  end
  return names
end

-- :Pack update [plugin]
vim.api.nvim_create_user_command("Pack", function(opts)
  local args = vim.split(opts.args, "%s+")
  local subcmd = args[1]

  if subcmd == "update" then
    local plugin_name = args[2]
    if plugin_name then
      vim.notify("Updating " .. plugin_name .. "...", vim.log.levels.INFO)
      vim.pack.update({ plugin_name })
    else
      vim.notify("Updating all plugins...", vim.log.levels.INFO)
      vim.pack.update()
    end
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
-- CONFORM.NVIM CONFIGURATION
-- ============================================================================

require("conform").setup({
  formatters_by_ft = {
    ["markdown.mdx"] = { "prettier" },
    c = { "clang_format" },
    cmake = { "cmake_format" },
    cpp = { "clang_format" },
    css = { "prettier" },
    eruby = { "rustywind" },
    go = { "gofmt" },
    graphql = { "prettier" },
    gdscript = { "gdformat" },
    handlebars = { "prettier" },
    html = { "prettier" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    json = { "biome", "prettier", stop_after_first = true },
    jsonc = { "prettier" },
    just = { "just" },
    less = { "prettier" },
    lua = { "stylua" },
    liquid = { "prettier" },
    markdown = { "prettier" },
    python = { "ruff" },
    ruby = { "rubyfmt", "syntax_tree", stop_after_first = true },
    rust = { "rustfmt" },
    scss = { "prettier" },
    sql = { "sqruff" },
    toml = { "taplo" },
    typescript = { "biome", "prettier", stop_after_first = true },
    typescriptreact = { "prettier" },
    vue = { "prettier" },
    yaml = { "prettier" },
    swift = { "swift", "swiftformat", stop_after_first = true },
    xml = { "xmlformatter" },
    zig = { "zigfmt" },
  },
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

set("n", { "<F8>", "gq" }, function()
  require("conform").format({ bufnr = vim.api.nvim_get_current_buf(), async = false })
end, { silent = true, desc = "Format buffer" })

set("i", "<F8>", function()
  require("conform").format({ bufnr = vim.api.nvim_get_current_buf(), async = true })
end, { silent = true, desc = "Format buffer" })

vim.api.nvim_create_user_command("Format", function(args)
  local range = nil
  if args.count ~= -1 then
    local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = {
      start = { args.line1, 0 },
      ["end"] = { args.line2, end_line:len() },
    }
  end

  local formatter = args.args ~= "" and { args.args } or nil
  require("conform").format({
    async = true,
    lsp_fallback = "fallback",
    range = range,
    formatters = formatter,
  })
end, {
  range = true,
  nargs = "?",
  desc = "Format buffer with optional formatter",
  complete = function(arg_lead, _, _)
    -- Get formatters for current buffer's filetype
    local conform = require("conform")
    local formatters = conform.list_formatters(0)

    local formatter_names = {}
    for _, formatter in ipairs(formatters) do
      table.insert(formatter_names, formatter.name)
    end

    return vim.tbl_filter(function(name)
      return name:find(arg_lead, 1, true) == 1
    end, formatter_names)
  end,
})

-- ============================================================================
-- MASON CONFIGURATION
-- ============================================================================

require("mason").setup({})
require("mason-lspconfig").setup({
  automatic_enable = {
    exclude = {
      "harper-ls",
      "harper_ls",
      "lua_ls",
      "lua-language-server",
    },
  },
})

-- ============================================================================
-- LSP CONFIGURATION
-- ============================================================================

vim.diagnostic.config({
  virtual_text = false,
  underline = {
    severity = vim.diagnostic.severity.ERROR,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ✘",
      [vim.diagnostic.severity.WARN] = "  ",
      [vim.diagnostic.severity.HINT] = "  ",
      [vim.diagnostic.severity.INFO] = "  ",
    },
  },
  float = {
    show_header = false,
    source = true,
  },
  update_in_insert = false,
})

-- Tiny inline diagnostic (gorgeous!)
if is_active("tiny-inline-diagnostic.nvim") then
  require("tiny-inline-diagnostic").setup({
    options = {
      show_source = true,
      multiple_diag_under_cursor = true,
    },
  })
end

-- LSP server configurations
vim.lsp.config("eslint", {
  settings = {
    format = { enable = false },
    rulesCustomizations = { { rule = "*", severity = "warn" } },
  },
})
vim.lsp.enable("eslint")

vim.lsp.config("tailwindcss", {
  settings = {
    classAttributes = { "class", "className", "class:list", "classList", "ngClass", "classes" },
  },
})
vim.lsp.enable("tailwindcss")

vim.lsp.enable("taplo")
vim.lsp.enable("yamlls")
vim.lsp.enable("zls")
vim.lsp.enable("markdown_oxide")
vim.lsp.enable("ruff")

vim.lsp.config("basedpyright", {
  settings = {
    pyright = {
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        ignore = { "*" },
      },
    },
  },
})
vim.lsp.enable("basedpyright")

vim.lsp.config("biome", {
  filetypes = { "typescript", "typescriptreact" },
})
vim.lsp.enable("biome")

vim.lsp.enable("html")
vim.lsp.enable("sourcekit")

vim.lsp.config("typos_lsp", {
  init_options = {
    diagnosticSeverity = "Warning",
  },
})
vim.lsp.enable("typos_lsp")

vim.lsp.config("vtsls", {
  root_markers = { "tsconfig.json", "jsconfig.json" },
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      suggest = { completeFunctionCalls = true },
    },
    vtsls = {
      experimental = {
        completion = {
          enableServerSideFuzzyMatch = true,
        },
      },
    },
  },
})
vim.lsp.enable("vtsls")

vim.lsp.config("denols", {
  root_markers = { "deno.json", "deno.jsonc" },
})
vim.lsp.enable("denols")

vim.lsp.config("sqruff", {
  root_markers = { ".sqruff" },
})
vim.lsp.enable("sqruff")

vim.lsp.enable("gdscript")

-- LSP Keymaps
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

set("n", "K", vim.lsp.buf.hover, { silent = true, desc = "Hover" })

-- ============================================================================
-- INC-RENAME CONFIGURATION
-- ============================================================================

require("inc_rename").setup({
  input_buffer_type = "snacks",
})

set("n", "grn", function()
  return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "Rename symbol" })

-- ============================================================================
-- NVIM-TREESITTER CONFIGURATION (main branch)
-- ============================================================================

-- Auto-install tree-sitter CLI if not present
if vim.fn.executable("tree-sitter") == 0 then
  vim.notify("tree-sitter CLI not found, installing...", vim.log.levels.INFO)

  local install_cmd
  if vim.fn.has("win32") == 1 then
    install_cmd = { "scoop", "install", "tree-sitter" }
  elseif vim.fn.has("mac") == 1 then
    install_cmd = { "brew", "install", "tree-sitter" }
  else
    -- Linux fallback - try npm as it's most universal
    install_cmd = { "npm", "install", "-g", "tree-sitter-cli" }
  end

  vim.system(install_cmd, { text = true }, function(obj)
    if obj.code == 0 then
      vim.notify("tree-sitter CLI installed successfully!", vim.log.levels.INFO)
    else
      vim.notify(
        "Failed to install tree-sitter CLI. Please install manually:\n"
          .. "  Windows: scoop install tree-sitter\n"
          .. "  macOS: brew install tree-sitter\n"
          .. "  Linux: npm install -g tree-sitter-cli",
        vim.log.levels.WARN
      )
    end
  end)
end

-- Setup nvim-treesitter
require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").papyrus = {
      install_info = {
        -- url = 'https://github.com/zimbulang/tree-sitter-zimbu',
        path = "~/Code/tree-sitter-papyrus/",
        -- optional entries:
        branch = "dev", -- only needed if different from default branch
        -- location = "parser", -- only needed if the parser is in subdirectory of a "monorepo"
        generate = true, -- only needed if repo does not contain pre-generated `src/parser.c`
        generate_from_json = false, -- only needed if repo does not contain `src/grammar.json` either
        queries = "queries", -- also install queries from given directory
      },
    }
  end,
})

require("treesitter-modules").setup({
  ensure_installed = {},
  ignore_install = {},
  sync_install = false,
  -- Automatically install missing parsers when entering buffer
  auto_install = true,
  fold = {
    enable = true,
  },
  highlight = {
    enable = true,
  },
  incremental_selection = {
    enable = true,
    -- set value to `false` to disable individual mapping
    keymaps = {
      init_selection = "<CR>",
      node_incremental = "<CR>",
      node_decremental = "<BS>",
    },
  },
  indent = {
    enable = true,
  },
})

-- ============================================================================
-- MINI.ICONS CONFIGURATION
-- ============================================================================

require("mini.icons").setup({})
MiniIcons.mock_nvim_web_devicons()

-- ============================================================================
-- MINI.SURROUND CONFIGURATION
-- ============================================================================

require("mini.surround").setup({
  mappings = {
    add = "ys",
    delete = "ds",
    find = "",
    find_left = "",
    highlight = "",
    replace = "cs",
    update_n_lines = "",
  },
  search_method = "cover_or_next",
})

-- ============================================================================
-- MINI.SPLITJOIN CONFIGURATION
-- ============================================================================

require("mini.splitjoin").setup({})

-- ============================================================================
-- MINI.AI CONFIGURATION
-- ============================================================================

local ai = require("mini.ai")
require("mini.ai").setup({
  n_lines = 500,
  custom_textobjects = {
    o = ai.gen_spec.treesitter({
      a = { "@block.outer", "@conditional.outer", "@loop.outer" },
      i = { "@block.inner", "@conditional.inner", "@loop.inner" },
    }, {}),
    f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
    c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
    t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
    d = { "%f[%d]%d+" }, -- digits
    e = { -- Word with case
      {
        "%u[%l%d]+%f[^%l%d]",
        "%f[%S][%l%d]+%f[^%l%d]",
        "%f[%P][%l%d]+%f[^%l%d]",
        "^[%l%d]+%f[^%l%d]",
      },
      "^().*()$",
    },
    g = function() -- Whole buffer
      local from = { line = 1, col = 1 }
      local to = {
        line = vim.fn.line("$"),
        col = math.max(vim.fn.getline("$"):len(), 1),
      }
      return { from = from, to = to }
    end,
    u = ai.gen_spec.function_call(), -- u for "Usage"
    U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name
  },
})

-- ============================================================================
-- NVIM-SPIDER CONFIGURATION
-- ============================================================================

require("spider").setup({
  skipInsignificantPunctuation = false,
})

set({ "n", "o", "x" }, "w", "<cmd>lua require('spider').motion('w')<CR>", { desc = "[count] words forward (subword)" })
set(
  { "n", "o", "x" },
  "e",
  "<cmd>lua require('spider').motion('e')<CR>",
  { desc = "Forward to end of word [count] (subword)" }
)
set({ "n", "o", "x" }, "b", "<cmd>lua require('spider').motion('b')<CR>", { desc = "[count] words backward (subword)" })

-- ============================================================================
-- FLASH.NVIM CONFIGURATION
-- ============================================================================

require("flash").setup({
  search = {
    multi_window = false,
    forward = false,
  },
  jump = {
    autojump = true,
  },
  modes = {
    search = {
      enabled = false,
    },
    char = {
      enabled = true,
      jump_labels = true,
      search = { wrap = false },
      highlight = { backdrop = false },
      multi_line = false,
      jump = {
        register = false,
        autojump = true,
      },
    },
  },
})

set({ "n", "x" }, "s", function()
  require("flash").jump({ search = { forward = true, wrap = false, multi_window = false } })
end, { desc = "Jump to pattern (forward)" })

set({ "n", "x" }, "S", function()
  require("flash").jump({ search = { forward = false, wrap = false, multi_window = false } })
end, { desc = "Jump to pattern (backward)" })

set("o", "r", function()
  require("flash").remote()
end, { desc = "Remote Flash" })

set({ "o", "x" }, "R", function()
  require("flash").treesitter_search()
end, { desc = "Treesitter Search" })

-- ============================================================================
-- GRUG-FAR CONFIGURATION
-- ============================================================================

require("grug-far").setup({
  engine = "ripgrep",
})

-- ============================================================================
-- MINI.ALIGN CONFIGURATION
-- ============================================================================

require("mini.align").setup({})

-- ============================================================================
-- SMART-SPLITS CONFIGURATION
-- ============================================================================

require("smart-splits").setup({})
set("n", "<C-h>", require("smart-splits").move_cursor_left)
set("n", "<C-j>", require("smart-splits").move_cursor_down)
set("n", "<C-k>", require("smart-splits").move_cursor_up)
set("n", "<C-l>", require("smart-splits").move_cursor_right)

-- ============================================================================
-- DIAL.NVIM CONFIGURATION
-- ============================================================================

local augend = require("dial.augend")

require("dial.config").augends:register_group({
  default = {
    augend.integer.alias.decimal,
    augend.integer.alias.decimal_int,
    augend.constant.alias.bool,
    augend.constant.new({
      elements = { "and", "or" },
      word = true,
      cyclic = true,
    }),
    augend.constant.new({
      elements = { "&&", "||" },
      word = false,
      cyclic = true,
    }),
    augend.constant.new({
      elements = { "it", "fit", "xit" },
      word = true,
      cyclic = true,
    }),
    augend.constant.new({
      elements = { "enable", "disable" },
      word = true,
      cyclic = true,
    }),
  },
  typescript = {
    augend.integer.alias.decimal,
    augend.integer.alias.hex,
    augend.constant.new({ elements = { "var", "let", "const" } }),
  },
})

set("n", "<C-a>", function()
  require("dial.map").manipulate("increment", "normal")
end, { desc = "Increment number/boolean/constant" })

set("n", "<C-x>", function()
  require("dial.map").manipulate("decrement", "normal")
end, { desc = "Decrement number/boolean/constant" })

set("v", "<C-a>", function()
  require("dial.map").manipulate("increment", "visual")
end, { desc = "Increment selection" })

set("v", "<C-x>", function()
  require("dial.map").manipulate("decrement", "visual")
end, { desc = "Decrement selection" })

-- ============================================================================
-- OIL.NVIM CONFIGURATION
-- ============================================================================

if is_active("oil.nvim") then
  require("oil").setup({
    win_options = {
      signcolumn = "yes:2",
    },
    delete_to_trash = true,
    watch_for_changes = true,
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["<C-s>"] = false,
      ["<C-h>"] = false,
      ["<C-t>"] = false,
      ["<C-l>"] = false,
    },
  })

  set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
end

if is_active("nvim-tinygit") then
  require("tinygit").setup({
    commit = {
      mediumLen = 50,
      maxLen = 100,
      preview = {
        loglines = 3,
      },
      wrap = "none",
      subject = {
        enforceType = false, -- disallow commit messages without a keyword
        types = {
          "fix",
          "feat",
          "chore",
          "docs",
          "refactor",
          "build",
          "test",
          "perf",
          "style",
          "revert",
          "ci",
          "break",
          "improv",
          "custom",
        },
      },
      spellcheck = true,
      openReferencedIssue = false,
    },
  })

  vim.api.nvim_create_user_command("Commit", function()
    require("tinygit").smartCommit({ pushIfClean = false })
  end, {
    desc = "Commit staged changes or all diffs",
  })
end

require("ts-comments").setup()
