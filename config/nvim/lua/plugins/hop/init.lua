local nnoremap = vim.keymap.nnoremap
local hop = require "hop"

hop.setup { keys = "etovxqpdygfblzhckisuran" }

--[[ nnoremap {
  "<Leader>w",
  function()
    hop.hint_words { current_line_only = true }
  end,
} ]]

nnoremap {
  "<Leader>w",
  function()
    hop.hint_words {}
  end,
}

nnoremap {
  "<Leader>e",
  function()
    require("plugins.hop.custom").hint_end_words()
  end,
}

nnoremap {
  "<Leader>l",
  function()
    hop.hint_lines_skip_whitespace()
  end,
}
