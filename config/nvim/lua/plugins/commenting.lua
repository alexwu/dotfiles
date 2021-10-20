require("kommentary.config").configure_language("default", {
  single_line_comment_string = "auto",
  multi_line_comment_strings = "auto",
  hook_function = function()
    require("ts_context_commentstring.internal").update_commentstring()
  end,
})

vim.api.nvim_set_keymap("n", "<C-_><C-_>", "<Plug>kommentary_line_default", {})
vim.api.nvim_set_keymap("n", "<C-_>", "<Plug>kommentary_motion_default", {})
vim.api.nvim_set_keymap("x", "<C-_>", "<Plug>kommentary_visual_default<C-c>", {})
