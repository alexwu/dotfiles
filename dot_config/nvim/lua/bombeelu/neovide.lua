local M = {}

function M.setup()
  vim.g.neovide_opacity = 0.95
  vim.g.neovide_input_use_logo = true
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"
  vim.g.neovide_remember_window_size = true

  -- Disable animations
  vim.g.neovide_position_animation_length = 0
  vim.g.neovide_cursor_animation_length = 0.00
  vim.g.neovide_cursor_trail_size = 0
  vim.g.neovide_cursor_animate_in_insert_mode = false
  vim.g.neovide_cursor_animate_command_line = false
  vim.g.neovide_scroll_animation_far_lines = 0
  vim.g.neovide_scroll_animation_length = 0.00

  -- System clipboard copy/paste/cut bindings
  set({ "n", "x" }, "<D-c>", [["+y]], { desc = "Copy to system clipboard" })
  set({ "n", "x" }, "<D-v>", [["+P]], { desc = "Paste from system clipboard" })
  set({ "i", "c" }, "<D-v>", "<C-r>+", { desc = "Paste from system clipboard" })
  set("t", "<D-v>", [[<C-\><C-n>"+Pi]], { desc = "Paste from system clipboard" })
  set({ "n", "x" }, "<D-x>", [["+x]], { desc = "Cut to system clipboard" })

  -- Select all
  set("n", "<D-a>", "ggVG", { desc = "Select all" })
  set("i", "<D-a>", "<Esc>ggVG", { desc = "Select all" })
end

return M
