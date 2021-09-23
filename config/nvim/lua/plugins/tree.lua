local nnoremap = vim.keymap.nnoremap
local tree_cb = require("nvim-tree.config").nvim_tree_callback
vim.g.nvim_tree_bindings = {
  { key = "h", cb = tree_cb "close_node" },
  { key = "l", cb = tree_cb "unroll_dir" },
}
nnoremap { "<leader>m", "<Cmd>NvimTreeToggle<CR>" }
nnoremap { "-", require("nvim-tree").open_buf_as_cwd }
