local actions = require("telescope.actions")
local trouble = require("trouble.providers.telescope")
local clear_line = function() vim.api.nvim_del_current_line() end

require("telescope").setup {
  defaults = {
    set_env = {["COLORTERM"] = "truecolor"},
    prompt_prefix = "❯ ",
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-u>"] = clear_line,
        ["<c-t>"] = trouble.open_with_trouble
      },
      n = {["<c-t>"] = trouble.open_with_trouble}
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

-- local snap = require "snap"
-- snap.register.map({"n"}, {"<C-p>"}, function()
--   snap.run {
--     producer = snap.get "consumer.fzf"(snap.get "producer.fd.file"),
--     select = snap.get"select.file".select,
--     multiselect = snap.get"select.file".multiselect,
--     views = {snap.get "preview.file"}
--   }
-- end)
