require "options"
require "globals"
require "plugins"
require "mappings"

require("snazzy").setup "dark"

require "plugins.treesitter"
vim.cmd [[ autocmd BufReadPost *.rbs,Steepfile set syntax=ruby ]]
