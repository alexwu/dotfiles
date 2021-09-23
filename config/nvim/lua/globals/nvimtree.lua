local tree_width = function(percentage)
  return math.min(35, vim.fn.round(vim.o.columns * percentage))
end

vim.g.nvim_tree_auto_close = 1
vim.g.nvim_tree_auto_ignore_ft = { "startify", "dashboard", "netrw", "help" }
vim.g.nvim_tree_auto_open = 1
vim.g.nvim_tree_disable_netrw = 1
vim.g.nvim_tree_disable_window_picker = 1
vim.g.nvim_tree_follow = 1
vim.g.nvim_tree_hijack_netrw = 1
vim.g.nvim_tree_ignore = { ".DS_Store" }
vim.g.nvim_tree_indent_markers = 0
vim.g.nvim_tree_quit_on_open = 1
vim.g.nvim_tree_respect_buf_cwd = 1
vim.g.nvim_tree_width = tree_width(0.2)
vim.g.nvim_tree_auto_ignore_ft = { "startify", "dashboard", "netrw", "help" }
vim.g.nvim_tree_ignore = { ".DS_Store" }
vim.g.nvim_tree_show_icons = {
  git = 1,
  folders = 1,
  files = 1,
  folder_arrows = 1,
}
vim.g.nvim_tree_special_files = {
  ["Gemfile"] = true,
  ["Gemfile.lock"] = true,
  ["package.json"] = true,
}
vim.g.nvim_tree_git_hl = 0
