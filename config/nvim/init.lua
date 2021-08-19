vim.g.polyglot_disabled = {
  "ruby.plugin", "typescript.plugin", "typescriptreact.plugin", "lua.plugin",
  "sensible"
}

require("mappings")
require("plugins")
require("colorscheme")
require("options")

require("plugins/treesitter")
-- require("plugins/lsp")
require("plugins/fuzzy-finder")
require("plugins/trouble")
require("plugins/todo-comments")
require("plugins/vim-test")
require("plugins/indent-blankline")
require("plugins/diffview")

vim.cmd [[ autocmd BufReadPost *.rbs,Steepfile set syntax=ruby ]]
