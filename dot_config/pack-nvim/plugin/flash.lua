vim.pack.add({ { src = gh("folke/flash.nvim") } })

require("flash").setup({
  search = {
    multi_window = false,
    forward = false,
  },
  jump = {
    autojump = true,
  },
  modes = {
    search = {
      enabled = false,
    },
    char = {
      enabled = false,
      jump_labels = true,
      search = { wrap = false },
      highlight = { backdrop = false },
      multi_line = false,
      jump = {
        register = false,
        autojump = true,
      },
    },
  },
})

local set = _G.set

set({ "n", "x" }, "s", function()
  require("flash").jump({ search = { forward = true, wrap = false, multi_window = false } })
end, { desc = "Jump to pattern (forward)" })

set({ "n", "x" }, "S", function()
  require("flash").jump({ search = { forward = false, wrap = false, multi_window = false } })
end, { desc = "Jump to pattern (backward)" })

set("o", "r", function()
  require("flash").remote()
end, { desc = "Remote Flash" })

set({ "o", "x" }, "R", function()
  require("flash").treesitter_search()
end, { desc = "Treesitter Search" })
