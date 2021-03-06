local actions = require("telescope.actions")

require("telescope").setup {
  defaults = {
    set_env = {["COLORTERM"] = "truecolor"},
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        -- ["<C-u>"] = vim.api.nvim_del_current_line,
      }
    }
  },
  extensions = {
    fzf_writer = {
      minimum_grep_characters = 2,
      minimum_files_characters = 2,
      use_highlighter = true
    },
    fzy_native = {override_generic_sorter = true, override_file_sorter = true}
  }
}

vim.api.nvim_set_keymap("n", "<C-p>",
                        "<cmd>lua require('telescope').extensions.fzf_writer.files()<cr>",
                        {noremap = true})
