if vim.g.loaded_bombeelu_autocmds then
  return
end
vim.g.loaded_bombeelu_autocmds = 1

require("bombeelu.autocmds").setup()
