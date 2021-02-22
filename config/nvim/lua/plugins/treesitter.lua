require'nvim-treesitter.configs'.setup {
  ensure_installed = "all",
  highlight = {
    enable = true,
    disable = { "ruby" },
  },
  indent = {
    enable = true,
    disable = { "ruby" },
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-s>",
      node_incremental = "<C-s>",
      scope_incremental = "<C-a>",
      node_decremental = "<C-x>",
    },
  }
}
