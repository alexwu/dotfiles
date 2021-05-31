vim.api.nvim_set_var("test#strategy", "floaterm")
vim.api.nvim_set_var("test#ruby#rspec#executable", "arch -x86_64 bundle exec rspec")
vim.api.nvim_set_var("test#ruby#rspec#patterns", "_spec.rb")
vim.api.nvim_set_var("test#ruby#rspec#options", {
  file = "--format documentation --force-color",
  suite = "--format documentation --force-color",
  nearest = "--format documentation --force-color"
})
vim.api.nvim_set_var("test#javascript#jest#options", "--color=always")

vim.api.nvim_set_var("test#javascript#jest#options", "--color=always")
vim.api.nvim_set_keymap("n", "t<C-n>", "<cmd>TestNearest<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-f>", "<cmd>TestFile<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-l>", "<cmd>TestLast<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-g>", "<cmd>TestVisit<CR>", {noremap = true})
