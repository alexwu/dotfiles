require"nvim-treesitter.configs".setup {
  ensure_installed = {
    "typescript", "ruby", "json", "jsonc", "rust", "bash", "go", "graphql",
    "html", "javascript", "lua", "python", "toml", "tsx", "css", "c", "cpp",
    "vue", "c_sharp", "swift", "yaml"
  },
  highlight = {enable = true},
  indent = {enable = true},
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<C-s>",
      node_incremental = "<C-s>",
      scope_incremental = "<C-a>",
      node_decremental = "<C-x>"
    }
  },
  playground = {
    enable = true,
    disable = {},
    updatetime = 25,
    persist_queries = false
  },
  rainbow = {enable = true},
  refactor = {highlight_definitions = {enable = true}},
  autotag = {enable = true},
  context_commentstring = {enable = true}
}
