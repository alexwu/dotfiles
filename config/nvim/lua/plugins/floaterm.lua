vim.g.floaterm_borderchars = "─│─│╭╮╯╰"

vim.api.nvim_set_keymap("n", "<F10>", "<cmd>FloatermToggle<CR>",
                        {noremap = true})
vim.api.nvim_set_keymap("t", "<F10>", "<cmd>FloatermToggle<CR>",
                        {noremap = true})
vim.g.floaterm_keymap_prev = "<F8>"
vim.g.floaterm_keymap_next = "<F9>"
