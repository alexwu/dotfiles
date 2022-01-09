local Terminal = require("toggleterm.terminal").Terminal

local rails_console = Terminal:new {
  cmd = "bundle exec rails console",
  direction = "float",
  float_opts = {
    border = "rounded",
    width = vim.fn.round(0.9 * vim.o.columns),
    height = vim.fn.round(0.9 * vim.o.lines),
    winblend = 0,
    highlights = { border = "FloatBorder", background = "Normal" },
  },
}

local rails_runner = Terminal:new {
  cmd = "bundle exec rails runner " .. vim.fn.expand "%",
  direction = "float",
  float_opts = {
    border = "rounded",
    width = vim.fn.round(0.9 * vim.o.columns),
    height = vim.fn.round(0.9 * vim.o.lines),
    winblend = 0,
    highlights = { border = "FloatBorder", background = "Normal" },
  },
  close_on_exit = false,
  on_open = function(term)
    vim.api.nvim_buf_set_keymap(
      term.bufnr,
      "n",
      "q",
      "<cmd>close<CR>",
      { noremap = true, silent = true }
    )
  end,
}

function Rails_console()
  rails_console:toggle()
end

_G.runner = function()
  rails_runner:toggle()
end

require("toggleterm").setup {
  size = function(term)
    if term.direction == "horizontal" then
      return 15
    elseif term.direction == "vertical" then
      return vim.o.columns * 0.4
    end
  end,
  open_mapping = [[<Bslash><Bslash>]],
  hide_numbers = true,
  shade_filetypes = {},
  shade_terminals = true,
  shading_factor = 1,
  start_in_insert = true,
  insert_mappings = true,
  persist_size = true,
  direction = "float",
  close_on_exit = true,
  float_opts = {
    border = "rounded",
    width = vim.fn.round(0.6 * vim.o.columns),
    height = vim.fn.round(0.6 * vim.o.lines),
    winblend = 0,
    highlights = { border = "FloatBorder", background = "Normal" },
  },
}

vim.cmd [[autocmd FileType toggleterm nmap <buffer> - +]]
vim.cmd [[autocmd FileType toggleterm nmap <buffer> <space><space> <cmd>ToggleTerm<CR>]]
vim.cmd [[autocmd FileType toggleterm tmap <buffer> <esc> <C-\><C-n>]]
vim.cmd [[command! -nargs=0 RConsole :lua Rails_console()<CR>]]
vim.cmd [[command! -nargs=0 RRunner :lua runner()<CR>]]
