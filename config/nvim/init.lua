require("mappings")
require("plugins")
require("colorscheme")
require("options")
require("statusline")

require("plugins/treesitter")
require("plugins/compe")
require("plugins/formatter")
require("plugins/floaterm")
require("plugins/fzf")
require("plugins/kommentary")
require("plugins/lspconfig")
require("plugins/telescope")
require("plugins/vim-test")
require("plugins/indent-blankline")

require("colorizer").setup()
require("gitsigns").setup()
require("nvim-autopairs").setup({
  disable_filetype = {"TelescopePrompt"},
  ignored_next_char = "[%w]"
})
require("nvim-ts-autotag").setup()

vim.cmd [[ autocmd BufWritePost plugins.lua PackerCompile ]]
