vim.g.polyglot_disabled = {
  "ruby.plugin", "typescript.plugin", "typescriptreact.plugin", "lua.plugin"
}

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
require("plugins/commenting")
require("plugins/lspconfig")
require("plugins/telescope")
require("plugins/trouble")
require("plugins/todo-comments")
require("plugins/vim-test")
require("plugins/indent-blankline")
require("plugins/diffview")

require("colorizer").setup()
require("gitsigns").setup({current_line_blame = false})
require("nvim-autopairs").setup({
  disable_filetype = {"TelescopePrompt"},
  ignored_next_char = "[%w]",
  check_ts = true
})
require("which-key").setup()

vim.g.symbols_outline = {
  highlight_hovered_item = true,
  show_guides = true,
  auto_preview = true,
  position = "right",
  keymaps = {
    close = "<Esc>",
    goto_location = "<Cr>",
    focus_location = "o",
    hover_symbol = "<C-space>",
    rename_symbol = "r",
    code_actions = "a"
  },
  lsp_blacklist = {}
}

vim.cmd [[ autocmd BufWritePost plugins.lua PackerCompile ]]
vim.cmd [[ autocmd BufReadPost *.rbs,Steepfile set syntax=ruby ]]
