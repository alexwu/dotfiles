require("indent_blankline").setup({
  use_treesitter = true,
  show_current_context = true,
  context_highlight = "Label",
  show_first_indent_level = false,
  buftype_exclude = { "help", "fzf", "lspinfo", "NvimTree", "nofile" },
  filetype_exclude = { "help", "fzf", "lspinfo", "NvimTree", "windline" },
  char = "▏",
})
