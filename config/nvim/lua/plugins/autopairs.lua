local npairs = require "nvim-autopairs"
npairs.setup {
  map_bs = false,
  check_ts = true,
  ignored_next_char = "[%w%.]",
}
npairs.add_rules(require "nvim-autopairs.rules.endwise-lua")
npairs.add_rules(require "nvim-autopairs.rules.endwise-ruby")
require("nvim-autopairs.completion.cmp").setup {
  map_cr = true,
  map_complete = true,
  auto_select = false,
  insert = false,
  map_char = {
    all = "(",
    tex = "{",
  },
}
