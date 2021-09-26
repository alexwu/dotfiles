local nnoremap = vim.keymap.nnoremap
local hop = require "hop"
hop.setup { keys = "etovxqpdygfblzhckisuran" }

nnoremap {
  "<Leader>w",
  function()
    hop.hint_words()
  end,
}

nnoremap {
  "<Leader>l",
  function()
    hop.hint_lines()
  end,
}
