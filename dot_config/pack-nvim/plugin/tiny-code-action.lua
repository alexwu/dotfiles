vim.pack.add({ { src = gh("rachartier/tiny-code-action.nvim") } })

require("tiny-code-action").setup({
  backend = "vim",
  picker = "snacks",
})

-- gra keymap is registered globally in init.lua to allow always-on activation;
-- this file just installs the plugin and sets defaults.
