if vim.g.loaded_bombeelu_visual_surround then
  return
end
vim.g.loaded_bombeelu_visual_surround = 1

require("bombeelu.visual-surround").setup()
