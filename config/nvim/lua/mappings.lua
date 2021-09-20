local keymap = require "astronauta.keymap"
local nnoremap = keymap.nnoremap
local xnoremap = keymap.xnoremap
local inoremap = keymap.inoremap

vim.g.mapleader = " "

nnoremap { "j", "gj" }
nnoremap { "k", "gk" }

nnoremap { "<C-j>", "5gj" }
nnoremap { "<C-k>", "5gk" }
nnoremap { "<C-h>", "5h" }
nnoremap { "<C-l>", "5l" }

xnoremap { "<C-j>", "5gj" }
xnoremap { "<C-k>", "5gk" }
xnoremap { "<C-h>", "5h" }
xnoremap { "<C-l>", "5l" }

inoremap { "<C-j>", "<Down>" }
inoremap { "<C-k>", "<Up>" }
inoremap { "<C-h>", "<Left>" }
inoremap { "<C-l>", "<Right>" }

nnoremap { "<CR>", "<Cmd>noh<CR><CR>", silent = true }
nnoremap { "<space><space>", "<C-^>" }

nnoremap { "<A-o>", "o<esc>" }
nnoremap { "<A-O>", "O<esc>" }

nnoremap { "<A-w>", "<Cmd>tabclose<CR>" }
nnoremap { "<A-t>", "<Cmd>tabnew<CR>" }

vim.cmd [[ autocmd FileType qf nnoremap <buffer> <silent> <ESC> :cclose<CR> ]]
vim.cmd [[command! -nargs=0 Trash :!trash %]]
vim.cmd [[command! -nargs=0 Delete :!trash %]]
