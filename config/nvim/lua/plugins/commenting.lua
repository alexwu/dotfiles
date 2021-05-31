vim.api.nvim_set_keymap("x", "<C-_>", "<Plug>Commentary", {})
vim.api.nvim_set_keymap("n", "<C-_>", "<Plug>Commentary", {})
vim.api.nvim_set_keymap("o", "<C-_>", "<Plug>Commentary", {})
vim.api.nvim_set_keymap("n", "<C-_><C-_>",
                        "<Plug>CommentaryLine", {})
