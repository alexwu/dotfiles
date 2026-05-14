local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("stevearc/oil.nvim") } })

require("oil").setup({
  default_file_explorer = true,
  win_options = {
    signcolumn = "yes:2",
  },
  delete_to_trash = true,
  watch_for_changes = true,
  view_options = {
    show_hidden = true,
  },
  keymaps = {
    ["<C-s>"] = false,
    ["<C-h>"] = false,
    ["<C-t>"] = false,
    ["<C-l>"] = false,
  },
})

_G.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
