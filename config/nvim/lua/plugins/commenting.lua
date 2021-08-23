require("kommentary.config").configure_language("default", {
  prefer_single_line_comments = true
})

vim.api.nvim_set_keymap("n", "<C-_><C-_>", "<Plug>kommentary_line_default", {})
vim.api.nvim_set_keymap("n", "<C-_>", "<Plug>kommentary_motion_default", {})
vim.api
  .nvim_set_keymap("x", "<C-_>", "<Plug>kommentary_visual_default<C-c>", {})
