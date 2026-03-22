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
