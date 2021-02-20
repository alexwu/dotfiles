local utils = require('utils')
local map = utils.map

map('i', '<S-Tab>', 'pumvisible() ? "\\<C-p>" : "\\<Tab>"', {expr = true})
map('i', '<Tab>', 'pumvisible() ? "\\<C-n>" : "\\<Tab>"', {expr = true})

map('n', 'j', 'gj')
map('n', 'k', 'gk')
map('n', '<C-j>', '5gj')
map('n', '<C-k>', '5gk')
map('n', '<C-h>', '5h')
map('n', '<C-l>', '5l')
