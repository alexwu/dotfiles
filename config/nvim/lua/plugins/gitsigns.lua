local keymap = require("astronauta.keymap")
local nnoremap = keymap.nnoremap

require("gitsigns").setup({current_line_blame = true})

nnoremap {"<Leader>hb", function() require("gitsigns").stage_buffer() end}
nnoremap {"M", function() require("gitsigns").blame_line({full = true}) end}
