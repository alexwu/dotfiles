vim.g.kommentary_create_default_mappings = false

vim.api.nvim_set_keymap("n", "<C-_><C-_>", "<Plug>kommentary_line_default", {})
vim.api.nvim_set_keymap("n", "<C-_>", "<Plug>kommentary_motion_default", {})
vim.api.nvim_set_keymap("x", "<C-_>", "<Plug>kommentary_visual_default<C-c>", {})

