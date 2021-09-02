local nnoremap = require("astronauta.keymap").nnoremap

vim.g.kitty_navigator_no_mappings = 1
nnoremap {"<A-h>", "<CMD>KittyNavigateLeft<cr>"}
nnoremap {"<A-l>", "<CMD>KittyNavigateRight<cr>"}
nnoremap {"<A-j>", "<CMD>KittyNavigateDown<cr>"}
nnoremap {"<A-k>", "<CMD>KittyNavigateUp<cr>"}
