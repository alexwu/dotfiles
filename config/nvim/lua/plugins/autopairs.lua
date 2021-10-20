local npairs = require "nvim-autopairs"
npairs.setup {
  map_bs = false,
  check_ts = true,
  ignored_next_char = "[%w%.]",
  map_c_w = false,
}

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
