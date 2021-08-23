require("plugins")
require("mappings")
require("options")

require("snazzy").setup("dark")

require("plugins/treesitter")
require("plugins/fuzzy-finder")

vim.cmd [[ autocmd BufReadPost *.rbs,Steepfile set syntax=ruby ]]
