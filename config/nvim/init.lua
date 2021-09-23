require "keymap"
require "options"
require "mappings"
require "globals"
require "plugins"

require("snazzy").setup "dark"

require "plugins.treesitter"

-- require "statusline"
vim.cmd [[autocmd BufReadPost *.rbs,Steepfile set syntax=ruby]]
