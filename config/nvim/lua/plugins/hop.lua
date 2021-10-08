local nnoremap = vim.keymap.nnoremap
local hop = require "hop"
hop.setup { keys = "etovxqpdygfblzhckisuran" }

nnoremap {
  "<Leader>b",
  function()
    hop.hint_words { direction = require("hop.hint").HintDirection.BEFORE_CURSOR }
  end,
}
nnoremap {
  "<Leader>w",
  function()
    hop.hint_words { direction = require("hop.hint").HintDirection.AFTER_CURSOR }
  end,
}

nnoremap {
  "<Leader>l",
  function()
    hop.hint_lines_skip_whitespace()
  end,
}
