if vim.g.loaded_bombeelu_knock or vim.g.vscode then
  return
end
vim.g.loaded_bombeelu_knock = 1

require("bombeelu.knock").setup()
