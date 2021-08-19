require"nvim-treesitter.configs".setup {
  highlight = {enable = true},
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
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner"
      }
    }
  },
  playground = {
    enable = true,
    disable = {},
    updatetime = 25,
    persist_queries = false
  },
  rainbow = {enable = false},
  refactor = {
    highlight_definitions = {enable = true},
    smart_rename = {enable = true, keymaps = {smart_rename = "<leader>rn"}},
    navigation = {
      enable = true,
      keymaps = {goto_definition_lsp_fallback = "gd"}
    }
  },
  autotag = {enable = true},
  context_commentstring = {enable = true},
  matchup = {enable = true},
  autopairs = {enable = true}
}
require("nvim-autopairs").setup({check_ts = true, fast_wrap = {}})
