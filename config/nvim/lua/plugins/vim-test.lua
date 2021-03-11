vim.api.nvim_set_var("test#strategy", "floaterm")
vim.api.nvim_set_var("test#ruby#rspec#executable", "bundle exec rspec")
vim.api.nvim_set_var("test#ruby#rspec#options", {
  file = "--format documentation",
  suite = "--format documentation",
  nearest = "--format documentation"
})
vim.api.nvim_set_var("test#ruby#jest#options", "--color=always")

vim.api.nvim_set_keymap("n", "t<C-n>", "<cmd>TestNearest<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-f>", "<cmd>TestFile<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-l>", "<cmd>TestLast<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-g>", "<cmd>TestVisit<CR>", {noremap = true})
