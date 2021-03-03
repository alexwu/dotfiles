require("maps")
require("options")

require("plugins")
require("colorscheme")
require("statusline")

require("plugins/autopairs")
require("plugins/compe")
require("plugins/formatter_config")
require("plugins/floaterm")
require("plugins/fzf")
require("plugins/gitsigns")
require("plugins/kommentary")
require("plugins/lightbulb")
require("plugins/lspconfig")
require("plugins/telescope")
require("plugins/treesitter")
require("plugins/vim-test")

vim.cmd [[ autocmd BufWritePost plugins.lua PackerCompile ]]
