vim.g.polyglot_disabled = {
  "ruby.plugin", "typescript.plugin", "typescriptreact.plugin", "lua.plugin"
}

require("mappings")
require("plugins")
require("colorscheme")
require("options")
require("statusline")

require("plugins/lsp")
require("plugins/treesitter")
require("plugins/compe")
require("plugins/formatter")
require("plugins/floaterm")
require("plugins/commenting")
require("plugins/fuzzy-finder")
require("plugins/trouble")
require("plugins/todo-comments")
require("plugins/vim-test")
require("plugins/indent-blankline")
require("plugins/diffview")
-- require("plugins/navigation")

require("colorizer").setup()
require("which-key").setup()
require("hop").setup {keys = "etovxqpdygfblzhckisuran"}

-- vim.cmd [[ autocmd BufWritePost plugins.lua PackerCompile ]]
vim.cmd [[ autocmd BufReadPost *.rbs,Steepfile set syntax=ruby ]]
