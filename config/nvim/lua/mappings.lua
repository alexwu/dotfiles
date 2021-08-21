vim.cmd [[runtime plugin/astronauta.vim]]

local utils = require("utils")
local map = utils.map
local tnoremap = vim.keymap.tnoremap

vim.g.mapleader = " "

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

map("n", "<CR>", "<Cmd>noh<CR><CR>", {silent = true})
map("n", "<space><space>", "<C-^>")

map("n", "<A-o>", "o<esc>")
map("n", "<A-O>", "O<esc>")

tnoremap {"<Esc>", "<Cmd>FloatermToggle<CR>"}

vim.cmd [[command! -nargs=0 Trash :!trash %]]
