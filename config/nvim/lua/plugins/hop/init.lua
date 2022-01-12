local set = vim.keymap.set
local hop = require "hop"

hop.setup { keys = "etovxqpdygfblzhckisuran" }

set("n", "<Leader>w", function()
  hop.hint_words {}
end)

set("n", "s", function()
  hop.hint_words {}
end)

set("n", "<Leader>e", function()
  require("plugins.hop.custom").hint_end_words()
end)

set("n", "<Leader>l", function()
  hop.hint_lines_skip_whitespace()
end)
