require("indent_blankline").setup({
  use_treesitter = true,
  show_current_context = true,
  context_highlight = "Label",
  buftype_exclude = {"help", "fzf", "lspinfo", "NvimTree"},
  char = "▏"
})
