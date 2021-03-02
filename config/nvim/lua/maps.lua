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

map("n", "<Bslash><Bslash>", "<C-^>")
map("n", "<c-s><c-a>", "<Cmd>w<cr>")
map("i", "<c-s><c-a>", "<esc><cmd>w<cr>")
