require"nvim-treesitter.configs".setup {
  ensure_installed = {
    "typescript", "ruby", "json", "jsonc", "rust", "bash", "go", "graphql",
    "html", "javascript", "lua", "python", "toml", "tsx", "css", "c", "cpp",
    "vue", "c_sharp", "swift", "yaml"
  },
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
  playground = {
    enable = true,
    disable = {},
    updatetime = 25,
    persist_queries = false
  },
  rainbow = {enable = false},
  refactor = {
    highlight_definitions = {enable = true},
    smart_rename = {enable = true, keymaps = {smart_rename = "grr"}}
  },
  autotag = {enable = true},
  context_commentstring = {enable = true}
}
