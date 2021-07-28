local o = vim.o
local utils = require("utils")
local opt = utils.opt

vim.cmd [[ syntax off ]]

local disabled_built_ins = {"gzip", "shada_plugin", "zipPlugin", "zip"}

for i = 1, 4 do vim.g["loaded_" .. disabled_built_ins[i]] = 1 end

vim.opt.autoindent = true
vim.opt.ch = 2
vim.opt.confirm = true
vim.opt.ignorecase = true
vim.opt.lazyredraw = true
vim.opt.backspace = "indent,eol,start"
vim.opt.cmdheight = 1
vim.opt.cursorline = true
vim.opt.directory = "~/.vim-tmp/,~/.tmp/,~/tmp/,/var/tmp/,/tmp"
vim.opt.mouse = "a"
vim.opt.updatetime = 250
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.expandtab = true
vim.opt.incsearch = true
vim.opt.laststatus = 2
vim.opt.linebreak = true
vim.opt.modelines = 1
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.joinspaces = false
vim.opt.showmode = false
vim.opt.wrap = false
vim.opt.number = true
vim.opt.numberwidth = 5
vim.opt.ruler = true
vim.opt.scrolloff = 5
vim.opt.shiftwidth = 2
vim.opt.showcmd = true
vim.opt.signcolumn = "yes"
vim.opt.smartcase = true
vim.opt.smarttab = true
vim.opt.softtabstop = 2
vim.opt.tabstop = 2
vim.opt.textwidth = 0
opt("shortmess", o.shortmess .. "Icq")
opt("tags", "./TAGS,TAGS")
opt("wildignore",
    "*.swp,.git,.svn,*.log,*.gif,*.jpeg,*.jpg,*.png,*.pdf,tmp/**,.DS_STORE,.DS_Store")

vim.cmd [[ au TextYankPost * silent! lua vim.highlight.on_yank{ higroup='IncSearch', timeout = 150 } ]]
vim.g.cursorhold_updatetime = 250

-- disable python 2
vim.g.loaded_python_provider = 0
