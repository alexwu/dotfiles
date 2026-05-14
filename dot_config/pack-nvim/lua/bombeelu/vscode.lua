local M = {}

function M.setup()
  local ok, vscode = pcall(require, "vscode")
  if not ok then
    return
  end

  vim.keymap.set("n", "<leader>f", function()
    vscode.action("workbench.action.quickOpen")
  end, { desc = "Quick open" })

  for _, lhs in ipairs({ "<F8>", "<leader>y" }) do
    vim.keymap.set("n", lhs, function()
      vscode.action("editor.action.formatDocument")
    end, { desc = "Format document" })
  end

  vim.keymap.set(
    "n",
    "<C-u>",
    [[<Cmd>call VSCodeNotify('cursorMove', { 'to': 'up', 'by': 'wrappedLine', 'value': v:count ? v:count : 1 })<CR>]],
    { desc = "Scroll up (wrapped)" }
  )
  vim.keymap.set(
    "n",
    "<C-d>",
    [[<Cmd>call VSCodeNotify('cursorMove', { 'to': 'down', 'by': 'wrappedLine', 'value': v:count ? v:count : 1 })<CR>]],
    { desc = "Scroll down (wrapped)" }
  )
end

return M
