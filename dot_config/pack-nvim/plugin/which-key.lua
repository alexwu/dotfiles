vim.pack.add({ { src = gh("folke/which-key.nvim") } })

require("which-key").setup({
  preset = "modern",
  spec = {
    {
      mode = { "n", "v" },
      { "[", group = "prev" },
      { "]", group = "next" },
    },
    {
      mode = { "n" },
      { "<Space>", group = "leader" },
      { "<leader>f", group = "picker" },
    },
  },
  delay = function(ctx)
    return ctx.plugin and 0 or 200
  end,
  triggers = {
    { "<auto>", mode = "nixsotc" },
    { "<leader>", mode = { "n", "v" } },
    { "<space>", mode = { "n" } },
  },
  icons = {
    rules = false,
  },
  layout = {
    height = { min = 4, max = 25 },
    width = { min = 20, max = 50 },
    spacing = 3,
    align = "center",
  },
})

local set = _G.set

set("n", "g?", function()
  require("which-key").show({ global = true })
end, { desc = "Keymaps (which-key)" })

set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer keymaps (which-key)" })
