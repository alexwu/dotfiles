local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("esmuellert/codediff.nvim") } })

require("codediff").setup({
  explorer = {
    view_mode = "tree",
  },
})

_G.set("n", "<leader>gD", function()
  local git_base = require("bombeelu.git")
  local _, merge_base = git_base.find_base_branch()

  -- CodeDiff takes two revisions: base vs HEAD
  vim.cmd("CodeDiff " .. merge_base .. " HEAD")
end, { desc = "CodeDiff (vs base branch)" })
