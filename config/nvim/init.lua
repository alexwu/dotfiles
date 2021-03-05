require("maps")
require("options")

require("plugins")
require("colorscheme")
require("statusline")

require("plugins/compe")
require("plugins/formatter_config")
require("plugins/floaterm")
require("plugins/fzf")
require("plugins/kommentary")
require("plugins/lightbulb")
require("plugins/lspconfig")
require("plugins/telescope")
require("plugins/treesitter")
require("plugins/vim-test")

require("colorizer").setup()
require("gitsigns").setup()
require("nvim-autopairs").setup({
  disable_filetype = {"TelescopePrompt"},
  ignored_next_char = "[%P%S]"
})

vim.cmd [[ autocmd BufWritePost plugins.lua PackerCompile ]]
