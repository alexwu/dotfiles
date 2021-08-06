vim.api.nvim_set_var("test#strategy", "floaterm")
vim.api.nvim_set_var("test#ruby#rspec#executable", "bundle exec rspec")
vim.api.nvim_set_var("test#ruby#rspec#patterns", "_spec.rb")
vim.api.nvim_set_var("test#ruby#rspec#options", {
  file = "--format documentation --force-color",
  suite = "--format documentation --force-color",
  nearest = "--format documentation --force-color"
})
vim.api.nvim_set_var("test#javascript#jest#options", "--color=always")
vim.api.nvim_set_var("test#typescript#jest#options", "--color=always")
vim.g.ultest_use_pty = 1
vim.g.ultest_unicode_icons = 1
vim.g.ultest_custom_patterns = {
  ["ruby#rspec"] = {["test"] = {"^\\s*it\\s+['\"](.+)['\"](,\\s+%{.+})*\\s+do"}, ["namespace"] = {"^describe"}}
}
-- vim.g.ultest_custom_patterns["ruby#rspec"]["test"] = "^\\s*test\\s+['\"](.+)['\"](,\\s+%{.+})*\\s+do"

vim.api.nvim_set_keymap("n", "t<C-n>", "<cmd>TestNearest<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-f>", "<cmd>TestFile<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-l>", "<cmd>TestLast<CR>", {noremap = true})
vim.api.nvim_set_keymap("n", "t<C-g>", "<cmd>TestVisit<CR>", {noremap = true})
