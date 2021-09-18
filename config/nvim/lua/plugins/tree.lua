local nnoremap = require("astronauta.keymap").nnoremap
local tree_cb = require("nvim-tree.config").nvim_tree_callback
vim.g.nvim_tree_bindings = {
  { key = "h", cb = tree_cb "close_node" },
  { key = "l", cb = tree_cb "unroll_dir" },
}
nnoremap { "-", require("nvim-tree").open_buf_as_cwd }
-- nnoremap { "-", "<Cmd>NvimTreeFindFile<CR>" }
nnoremap { "<leader>m", "<Cmd>NvimTreeToggle<CR>" }
