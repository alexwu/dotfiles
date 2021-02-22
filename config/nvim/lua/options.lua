local o, wo, bo = vim.o, vim.wo, vim.bo
local utils = require('utils')
local opt = utils.opt
local autocmd = utils.autocmd
local map = utils.map

local buffer = {o, bo}
local window = {o, wo}

opt('autoindent', true, buffer)
opt('backspace', 'indent,eol,start')
opt('ch', 2)
opt('cmdheight', 1)
opt('confirm', true)
opt('cursorline', true, window)
opt('directory', '~/.vim-tmp/,~/.tmp/,~/tmp/,/var/tmp/,/tmp')
opt('encoding', 'utf-8')
opt('expandtab', true, buffer)
opt('hidden', true)
opt('history', 50)
opt('hlsearch', true)
opt('ignorecase', true)
opt('incsearch', true)
opt('laststatus', 2)
opt('lazyredraw', true)
opt('linebreak', true)
opt('listchars', 'tab:▶ ,eol:¬')
opt('loadplugins', true)
opt('modelines', 1)
opt('mouse', 'a')
opt('backup', false)
opt('joinspaces', false)
opt('showmode', false)
opt('wrap', false)
opt('number', true, window)
opt('numberwidth', 5, window)
opt('ruler', true)
opt('scrolloff', 5)
opt('shell', '/bin/zsh')
opt('shiftwidth', 2, buffer)
opt('shortmess', o.shortmess .. 'c')
opt('showcmd', true)
opt('signcolumn', 'yes')
opt('smartcase', true)
opt('smarttab', true)
opt('softtabstop', 2, buffer)
opt('tabstop', 2, buffer)
opt('tags', './TAGS,TAGS')
opt('textwidth', 0)
opt('timeoutlen', 250)
opt('updatetime', 300)
opt('wildignore', '*.swp,.git,.svn,*.log,*.gif,*.jpeg,*.jpg,*.png,*.pdf,tmp/**,.DS_STORE,.DS_Store')
opt('termguicolors', true)
o.completeopt = 'menuone,noselect'

autocmd('highlight_yank',
  'TextYankPost * silent! lua require"vim.highlight".on_yank{ higroup="IncSearch", timeout=200 }',
  true
)

-- Slower but more accurate syntax highlighting for javascript/typescript files
-- autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
-- autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear
