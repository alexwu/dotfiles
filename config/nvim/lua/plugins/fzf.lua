local nnoremap = require("astronauta.keymap").nnoremap

require("fzf-lua").setup {
  win_border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
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
  },
  grep = {
    prompt = "Grep ❯ ",
    input_prompt = "Grep For❯ ",
    git_icons = true,
    file_icons = true,
    color_icons = true,
  },
  file_icon_colors = {
    ["lua"] = "blue",
    ["rb"] = "red",
    ["gemfile"] = "red",
    ["js"] = "yellow",
    ["jsx"] = "cyan",
    ["ts"] = "blue",
    ["tsx"] = "cyan",
  },
  fzf_binds = {
    "f2:toggle-preview",
    "f3:toggle-preview-wrap",
    "shift-down:preview-page-down",
    "shift-up:preview-page-up",
    "ctrl-d:half-page-down",
    "ctrl-u:half-page-up",
    "ctrl-f:page-down",
    "ctrl-b:page-up",
    "ctrl-a:toggle-all",
    "ctrl-u:clear-query",
  },
  window_on_create = function()
    vim.api.nvim_buf_set_keymap(0, "t", "<Esc>", "<C-c>", { nowait = true, silent = true })
  end,
  lsp = { async_or_timeout = 3000 },
}

-- nnoremap {"<Leader>f", function() require("fzf-lua").files() end}
-- nnoremap {"<Leader>rg", function() require("fzf-lua").live_grep() end}
-- nnoremap {"<Leader>ag", function() require("fzf-lua").live_grep() end}

vim.cmd [[ command! -nargs=0 Rg :lua require('fzf-lua').live_grep()<CR> ]]

vim.cmd [[ autocmd FileType fzf inoremap <buffer> <Esc> :close<CR>]]
