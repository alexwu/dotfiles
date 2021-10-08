local nnoremap = vim.keymap.nnoremap
local tree = require "nvim-tree"
local tree_cb = require("nvim-tree.config").nvim_tree_callback

local tree_width = function(percentage)
  return math.min(40, vim.fn.round(vim.o.columns * percentage))
end

vim.g.nvim_tree_disable_window_picker = 1
vim.g.nvim_tree_respect_buf_cwd = 1
vim.g.nvim_tree_highlight_opened_files = 1
vim.g.nvim_tree_quit_on_open = 1
vim.g.nvim_tree_special_files = {
  ["Gemfile"] = 1,
  ["Gemfile.lock"] = 1,
  ["package.json"] = 1,
}
vim.g.show_icons = {
  git = 1,
  folders = 1,
  files = 1,
  folder_arrows = 1,
}

tree.setup {
  auto_close = true,
  disable_netrw = true,
  ignore_ft_on_setup = { "startify", "dashboard", "netrw", "help" },
  view = {
    auto_resize = true,
    width = tree_width(0.2),
    mappings = {
      list = {
        { key = "h", cb = tree_cb "close_node" },
        { key = "l", cb = tree_cb "unroll_dir" },
      },
    },
  },
  update_focused_file = {
    enable = true,
    update_cwd = true,
    ignore_list = { "help" },
  },
}

nnoremap { "<leader>m", "<Cmd>NvimTreeToggle<CR>" }
nnoremap {
  "-",
  function()
    tree.find_file(true)
  end,
}
