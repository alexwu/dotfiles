if vim.g.loaded_bombeelu_vscode then
  return
end
vim.g.loaded_bombeelu_vscode = 1

if vim.g.vscode then
  require("bombeelu.vscode").setup()
end
