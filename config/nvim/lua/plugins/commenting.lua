local nnoremap = vim.keymap.nnoremap
local xnoremap = vim.keymap.xnoremap

require("kommentary.config").configure_language("default", {
  prefer_single_line_comments = true,
})

nnoremap { "<C-_><C-_>", "<Plug>kommentary_line_default" }
nnoremap { "<C-_>", "<Plug>kommentary_motion_default" }
xnoremap { "<C-_>", "<Plug>kommentary_visual_default<C-c>" }
