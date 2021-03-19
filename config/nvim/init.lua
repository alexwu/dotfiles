require("mappings")
require("plugins")
require("colorscheme")
require("options")
require("statusline")

require("plugins/compe")
require("plugins/formatter")
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
require("nvim-ts-autotag").setup()

vim.cmd [[ autocmd BufWritePost plugins.lua PackerCompile ]]
