require"nvim-treesitter.configs".setup {
  highlight = {enable = true, disable = {"ruby"}},
  indent = {enable = true, disable = {"ruby"}},
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-s>",
      node_incremental = "<C-s>",
      scope_incremental = "<C-a>",
      node_decremental = "<C-x>"
    }
  },
  refactor = {highlight_definitions = {enable = true}},
  playground = {
    enable = true,
    disable = {},
    updatetime = 25,
    persist_queries = false
  },
  autotag = {enable = true}
}
