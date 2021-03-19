local utils = require("utils")
local map = utils.map

vim.g.mapleader = " "

map("i", "<S-Tab>", "pumvisible() ? \"\\<C-p>\" : \"\\<Tab>\"", {expr = true})
map("i", "<Tab>", "pumvisible() ? \"\\<C-n>\" : \"\\<Tab>\"", {expr = true})

map("n", "j", "gj")
map("n", "k", "gk")
map("n", "<C-j>", "5gj")
map("n", "<C-k>", "5gk")
map("n", "<C-h>", "5h")
map("n", "<C-l>", "5l")

map("x", "<C-j>", "5gj")
map("x", "<C-k>", "5gk")
map("x", "<C-h>", "5h")
map("x", "<C-l>", "5l")

map("i", "<C-j>", "<Down>")
map("i", "<C-k>", "<Up>")
map("i", "<C-h>", "<Left>")
map("i", "<C-l>", "<Right>")

map("n", "<leader>m", "<cmd>NvimTreeToggle<cr>")
map("n", "<leader>t", "<Cmd>Telescope<cr>")

map("n", "<C-t>", "<Cmd>tabedit<cr>")
map("n", "<space><space>", "<C-^>")

vim.api.nvim_set_keymap("n", "<Bslash>w", "<cmd>lua require'hop'.hint_words()<cr>", {})
vim.api.nvim_set_keymap("n", "<Bslash>l", "<cmd>lua require'hop'.hint_lines()<cr>", {})
vim.api.nvim_set_keymap("n", "<Bslash>c", "<cmd>lua require'hop'.hint_char1()<cr>", {})

vim.cmd [[command! -nargs=0 Trash :!trash %]]
