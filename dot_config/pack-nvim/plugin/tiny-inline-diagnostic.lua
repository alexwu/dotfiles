local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("rachartier/tiny-inline-diagnostic.nvim") } })

require("tiny-inline-diagnostic").setup({
  options = {
    show_source = { enabled = true },
    show_all_diags_on_cursorline = true,
  },
})

if Snacks then
  Snacks.toggle
    .new({
      id = "tiny-inline-diagnostic",
      name = "Inline Diagnostics",
      get = function()
        return require("tiny-inline-diagnostic").is_enabled()
      end,
      set = function(state)
        if state then
          require("tiny-inline-diagnostic").enable()
        else
          require("tiny-inline-diagnostic").disable()
        end
      end,
    })
    :map("<leader>up")
end
