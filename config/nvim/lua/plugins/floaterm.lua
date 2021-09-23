local keymap = vim.keymap
local tnoremap = keymap.tnoremap
local nnoremap = keymap.nnoremap

vim.g.floaterm_borderchars = "─│─│╭╮╯╰"
vim.g.floaterm_width = 0.9
vim.g.floaterm_height = 0.9

nnoremap { "<F10>", "<Cmd>FloatermToggle<CR>" }
tnoremap { "<F10>", "<Cmd>FloatermToggle<CR>" }

vim.cmd [[autocmd FileType floaterm nmap <buffer> - +]]
vim.cmd [[autocmd FileType floaterm nmap <buffer> <space><space> <cmd>FloatermToggle<CR>]]
