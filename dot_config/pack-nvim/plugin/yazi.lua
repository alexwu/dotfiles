local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({
  { src = gh("mikavilpas/yazi.nvim"), version = vim.version.range("*") },
})

require("yazi").setup({
  open_for_directories = false,
  keymaps = {
    show_help = "<f1>",
  },
})

local set = _G.set
set({ "n", "v" }, "<leader>-", "<cmd>Yazi<cr>", { desc = "Open yazi at the current file" })
set("n", "<leader>cw", "<cmd>Yazi cwd<cr>", { desc = "Open yazi in nvim's working directory" })
set("n", "<c-up>", "<cmd>Yazi toggle<cr>", { desc = "Resume the last yazi session" })
