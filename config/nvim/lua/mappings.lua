local utils = require("utils")
local map = utils.map
local keymap = require("astronauta.keymap")
local nnoremap = keymap.nnoremap

vim.g.mapleader = " "

nnoremap {"j", "gj"}
nnoremap {"k", "gk"}

nnoremap {"<C-j>", "5gj"}
nnoremap {"<C-k>", "5gk"}
nnoremap {"<C-h>", "5h"}
nnoremap {"<C-l>", "5l"}

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

vim.cmd [[command! -nargs=0 Trash :!trash %]]
vim.cmd [[command! -nargs=0 Delete :!trash %]]
