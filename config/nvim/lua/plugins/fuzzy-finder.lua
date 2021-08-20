local map = vim.api.nvim_set_keymap
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
    fzf = {
      fuzzy = true,
      override_generic_sorter = false,
      override_file_sorter = true,
      case_mode = "smart_case"
    }
  }
}
require("telescope").load_extension("fzf")

require"fzf-lua".setup {
  win_height = 0.5,
  win_width = 0.4,
  win_row = 0.30,
  win_col = 0.50,
  win_border = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"},
  fzf_args = "--color 'fg:#f9f9ff,fg+:#f3f99d,hl:#5af78e,hl+:#5af78e,spinner:#5af78e,pointer:#ff6ac1,info:#5af78e,prompt:#9aedfe,gutter:#282a36'",
  fzf_layout = "default",
  preview_cmd = "",
  preview_border = "border",
  preview_wrap = "nowrap",
  preview_opts = "nohidden",
  preview_vertical = "down:45%",
  preview_horizontal = "right:60%",
  preview_layout = "flex",
  flip_columns = 120,
  bat_theme = "Sublime Snazzy",
  files = {
    prompt = "❯ ",
    cmd = "",
    git_icons = true,
    file_icons = true,
    color_icons = true,
    preview_opts = "hidden"
  },
  grep = {
    prompt = "Grep ❯ ",
    input_prompt = "Grep For❯ ",
    git_icons = true,
    file_icons = true,
    color_icons = true
  },
  file_icon_colors = { -- override colors for extensions
    ["lua"] = "blue",
    ["rb"] = "red",
    ["gemfile"] = "red",
    ["js"] = "yellow",
    ["jsx"] = "cyan",
    ["ts"] = "blue",
    ["tsx"] = "cyan"
  },
  fzf_binds = {
    "f2:toggle-preview", "f3:toggle-preview-wrap",
    "shift-down:preview-page-down", "shift-up:preview-page-up",
    "ctrl-d:half-page-down", "ctrl-u:half-page-up", "ctrl-f:page-down",
    "ctrl-b:page-up", "ctrl-a:toggle-all", "ctrl-u:clear-query"
  },
  window_on_create = function()
    vim.api.nvim_buf_set_keymap(0, "t", "<Esc>", "<C-c>",
                                {nowait = true, silent = true})
    vim.api.nvim_buf_set_keymap(0, "t", "<Leader>t", "<C-c>",
                                {nowait = true, silent = true})
  end
}

map("n", "<Leader>f", "<cmd>lua require('fzf-lua').files()<CR>",
    {noremap = true})
--[[ vim.api.nvim_set_keymap("n", "<Leader>f", "<cmd>lua require('telescope.builtin').find_files()<cr>",
                        {noremap = true}) ]]
--[[ local snap = require "snap"
snap.maps {
  {"<Leader><Leader>", snap.config.file {producer = "ripgrep.file"}},
  {"<Leader>fb", snap.config.file {producer = "vim.buffer"}},
  {"<Leader>fo", snap.config.file {producer = "vim.oldfile"}},
  {"<Leader>ff", snap.config.vimgrep {}}
} ]]

-- map("n", "<leader>t", "<Cmd>Telescope<cr>")
map("n", "<leader>t", "<Cmd>FzfLua<cr>", {noremap = true})
vim.cmd [[ command! -nargs=0 Rg :lua require('fzf-lua').live_grep()<CR> ]]
vim.cmd [[ command! -nargs=0 References :lua require('fzf-lua').lsp_references()<CR> ]]
vim.cmd [[ autocmd FileType fzf inoremap <buffer> <Esc> :close<CR> ]]
