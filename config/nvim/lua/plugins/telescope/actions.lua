local M = {}

M.clear_line = function(prompt_bufnr)
  vim.api.nvim_del_current_line()
end

return M
