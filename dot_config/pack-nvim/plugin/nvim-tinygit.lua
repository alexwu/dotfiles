local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("chrisgrieser/nvim-tinygit") } })

require("tinygit").setup({
  commit = {
    mediumLen = 50,
    maxLen = 100,
    preview = {
      loglines = 3,
    },
    wrap = "none",
    subject = {
      enforceType = false,
      types = {
        "fix",
        "feat",
        "chore",
        "docs",
        "refactor",
        "build",
        "test",
        "perf",
        "style",
        "revert",
        "ci",
        "break",
        "improv",
        "custom",
      },
    },
    spellcheck = true,
    openReferencedIssue = false,
  },
})

vim.api.nvim_create_user_command("Commit", function()
  require("tinygit").smartCommit({ pushIfClean = false })
end, {
  desc = "Commit staged changes or all diffs",
})
