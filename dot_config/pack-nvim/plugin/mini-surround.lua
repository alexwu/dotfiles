vim.pack.add({ { src = gh("nvim-mini/mini.surround") } })

require("mini.surround").setup({
  mappings = {
    add = "ys",
    delete = "ds",
    find = "",
    find_left = "",
    highlight = "",
    replace = "cs",
    update_n_lines = "",
  },
  search_method = "cover_or_next",
})
