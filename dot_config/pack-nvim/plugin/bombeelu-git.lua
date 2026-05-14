if vim.g.loaded_bombeelu_git then
  return
end
vim.g.loaded_bombeelu_git = 1

require("bombeelu.git").setup()
