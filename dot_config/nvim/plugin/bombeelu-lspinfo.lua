if vim.g.loaded_bombeelu_lspinfo then
  return
end
vim.g.loaded_bombeelu_lspinfo = 1

vim.api.nvim_create_user_command("LspInfo", function()
  require("bombeelu.lspinfo").show()
end, { desc = "Show LSP client info in a floating window" })
