if vim.g.loaded_bombeelu_neovide then
  return
end
vim.g.loaded_bombeelu_neovide = 1

if vim.g.neovide then
  require("bombeelu.neovide").setup()
end
