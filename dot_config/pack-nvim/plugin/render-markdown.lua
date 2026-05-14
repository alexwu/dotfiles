local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("MeanderingProgrammer/render-markdown.nvim") } })

require("render-markdown").setup({
  anti_conceal = { enabled = false },
})
