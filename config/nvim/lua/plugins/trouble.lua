require("trouble").setup { mode = "lsp_document_diagnostics" }
vim.api.nvim_set_keymap(
  "n",
  "<leader>xx",
  "<cmd>TroubleToggle<cr>",
  { silent = true, noremap = true }
)
vim.api.nvim_set_keymap(
  "n",
  "<leader>xd",
  "<cmd>Trouble lsp_workspace_diagnostics<cr>",
  { silent = true, noremap = true }
)
