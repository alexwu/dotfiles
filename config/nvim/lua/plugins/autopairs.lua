local npairs = require "nvim-autopairs"
npairs.setup {
  map_bs = false,
  check_ts = true,
  ignored_next_char = "[%w%.]",
  map_c_w = false,
}
-- npairs.add_rules(require "nvim-autopairs.rules.endwise-lua")
-- npairs.add_rules(require "nvim-autopairs.rules.endwise-ruby")
-- local ts_conds = require('nvim-autopairs.ts-conds')

-- -- press % => %% is only inside comment or string
-- npairs.add_rules({
--   Rule("%", "%", "lua")
--     :with_pair(ts_conds.is_ts_node({'string','comment'})),
--   Rule("$", "$", "lua")
--     :with_pair(ts_conds.is_not_ts_node({'function'}))
-- })
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
