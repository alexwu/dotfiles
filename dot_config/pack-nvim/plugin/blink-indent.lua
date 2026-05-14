local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("saghen/blink.indent") } })
