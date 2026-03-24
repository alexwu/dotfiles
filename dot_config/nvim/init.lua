vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("mappings")

require("lazy").setup({
  spec = { { import = "plugins" } },
  dev = { path = "~/Code/neovim/plugins", patterns = { "alexwu" } },
  install = { colorscheme = { "snazzy" } },
  checker = { enabled = false },
  change_detection = { notify = false },
})

require("options")

-- New line without entering insert mode
local bu = require("bu")
local keys = bu.keys
local repeatable = bu.nvim.repeatable

set(
  "n",
  { "<A-o>", "<D-CR>" },
  repeatable(function()
    keys.o({ esc = true })
  end),
  { desc = "Add a new line below the current line" }
)

set(
  "n",
  { "<A-O>" },
  repeatable(function()
    keys.O({ esc = true })
  end),
  { desc = "Add a new line above the current line" }
)

-- Visual surround (parens, quotes, brackets, tags)
require("bombeelu.visual-surround").setup()

-- Git base branch detection (async PR cache + tiered fallbacks)
require("bombeelu.git").setup()
