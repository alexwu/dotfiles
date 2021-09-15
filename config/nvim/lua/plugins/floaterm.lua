local keymap = require "astronauta.keymap"
local tnoremap = keymap.tnoremap
local nnoremap = keymap.nnoremap

vim.g.floaterm_borderchars = "─│─│╭╮╯╰"

nnoremap { "<F10>", "<Cmd>FloatermToggle<CR>" }
tnoremap { "<F10>", "<Cmd>FloatermToggle<CR>" }

vim.cmd [[autocmd FileType floaterm nmap <buffer> - +]]
vim.cmd [[autocmd FileType floaterm nmap <buffer> <space><space> <cmd>FloatermToggle<CR>]]
