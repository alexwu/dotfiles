vim.g.floaterm_borderchars = "─│─│╭╮╯╰"
vim.g.floaterm_height = 0.6
vim.g.floaterm_weight = 0.6

vim.api.nvim_set_keymap("n", "<F10>", "<cmd>FloatermToggle<CR>",
                        {noremap = true})
vim.api.nvim_set_keymap("t", "<F10>", "<cmd>FloatermToggle<CR>",
                        {noremap = true})
vim.api.nvim_set_keymap("n", "<C-t>", "<cmd>FloatermToggle<CR>",
                        {noremap = true})
vim.api.nvim_set_keymap("t", "<C-t>", "<cmd>FloatermToggle<CR>",
                        {noremap = true})
vim.api.nvim_set_keymap("n", "[t", "<cmd>FloatermPrev<CR>",
                        {noremap = true})
vim.api.nvim_set_keymap("t", "]t", "<cmd>FloatermNext<CR>",
                        {noremap = true})
