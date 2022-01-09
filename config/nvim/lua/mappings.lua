local keymap = vim.keymap
local set = keymap.set

vim.g.mapleader = " "

set ("n", "j", "gj")
set ("n", "k", "gk" )

set ({"n", "x"}, "<C-j>", "5gj" )
set ({"n", "x"}, "<C-k>", "5gk" )
set ({"n", "x"}, "<C-h>", "5h" )
set ({"n", "x"}, "<C-l>", "5l" )

set ("i", "<C-j>", "<Down>" )
set ("i", "<C-k>", "<Up>" )
set ("i", "<C-h>", "<Left>" )
set ("i", "<C-l>", "<Right>" )

set ("n", "<ESC>", "<cmd>noh<CR>" )
set ("x", "<F2>", "\"*y" )
set ("n", "<A-BS>", "db" )
set ("i", "<A-BS>", "<C-W>" )

set ("n", "<A-o>", "o<esc>" )
set ("n", "<A-O>", "O<esc>" )

vim.cmd [[autocmd FileType qf set <buffer> <silent> <ESC> :cclose<CR>]]
vim.cmd [[autocmd FileType help set <buffer> <silent> gd <C-]>]]

vim.api.nvim_add_user_command("Trash", "!trash %", { bang = true, nargs = 0 })
vim.api.nvim_add_user_command("Delete", "!trash %", { bang = true, nargs = 0 })
