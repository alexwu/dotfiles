vim.pack.add({ { src = gh("rachartier/tiny-code-action.nvim") } })

require("tiny-code-action").setup({
  backend = "vim",
  picker = "snacks",
})
