if vim.fn.has("gui_vimr") ~= 1 then
  local tree_cb = require"nvim-tree.config".nvim_tree_callback
  vim.g.nvim_tree_auto_open = 1
  vim.g.nvim_tree_auto_close = 1
  vim.g.nvim_tree_quit_on_open = 0
  vim.g.nvim_tree_indent_markers = 1
  vim.g.nvim_tree_disable_netrw = 0
  vim.g.nvim_tree_hijack_netrw = 0
  vim.g.nvim_tree_follow = 1
  vim.g.nvim_tree_auto_ignore_ft = {"startify", "dashboard", "netrw"}
  vim.g.nvim_tree_ignore = {".DS_Store"}
  vim.g.nvim_tree_width = "25%"
  vim.api.nvim_set_keymap("n", "<leader>m", "<Cmd>NvimTreeToggle<CR>", {})
end
