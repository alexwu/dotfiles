local o, wo, bo = vim.o, vim.wo, vim.bo
local utils = require("utils")
local opt = utils.opt

local buffer = {o, bo}
local window = {o, wo}

vim.opt.autoindent = true
opt("backspace", "indent,eol,start")
vim.opt.ch = 2
opt("cmdheight", 1)
vim.opt.confirm = true
opt("cursorline", true, window)
opt("directory", "~/.vim-tmp/,~/.tmp/,~/tmp/,/var/tmp/,/tmp")
opt("expandtab", true, buffer)
opt("hlsearch", true)
opt("incsearch", true)
opt("laststatus", 2)
opt("lazyredraw", true)
opt("linebreak", true)
opt("modelines", 1)
opt("mouse", "a")
opt("backup", false)
opt("joinspaces", false)
opt("showmode", false)
opt("wrap", false, window)
opt("number", true, window)
opt("numberwidth", 5, window)
opt("ruler", true)
opt("scrolloff", 5)
opt("shell", "/bin/zsh")
opt("shiftwidth", 2, buffer)
opt("shortmess", o.shortmess .. "Icq")
opt("showcmd", true)
opt("signcolumn", "yes", window)
vim.opt.ignorecase = true
opt("smartcase", true)
opt("smarttab", true)
opt("softtabstop", 2, buffer)
opt("tabstop", 2, buffer)
opt("tags", "./TAGS,TAGS")
opt("textwidth", 0)
opt("updatetime", 100)
opt("wildignore",
    "*.swp,.git,.svn,*.log,*.gif,*.jpeg,*.jpg,*.png,*.pdf,tmp/**,.DS_STORE,.DS_Store")
opt("termguicolors", true)
vim.opt.syntax = "0"
vim.opt.lazyredraw = true

vim.cmd [[ au TextYankPost * silent! lua vim.highlight.on_yank{ higroup='IncSearch', timeout = 150 } ]]
vim.g.cursorhold_updatetime = 100

if vim.fn.has("gui_vimr") ~= 1 then
  vim.g.nvim_tree_auto_open = 1
  vim.g.nvim_tree_auto_close = 1
  vim.g.nvim_tree_quit_on_open = 0
  vim.g.nvim_tree_indent_markers = 1
  vim.g.nvim_tree_disable_netrw = 1
  vim.g.nvim_tree_hijack_netrw = 1
  vim.g.nvim_tree_auto_ignore_ft = {"startify", "dashboard", "netrw"}
  vim.g.nvim_tree_ignore = {".DS_Store"}
end

-- disable python 2
vim.g.loaded_python_provider = 0
