require("mappings")
require("plugins")
require("options")

require("snazzy").setup("dark")

require("plugins/treesitter")
require("plugins/fuzzy-finder")
require("plugins/vim-test")

vim.cmd [[ autocmd BufReadPost *.rbs,Steepfile set syntax=ruby ]]
