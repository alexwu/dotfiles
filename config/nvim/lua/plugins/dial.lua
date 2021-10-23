local dial = require "dial"

dial.augends["custom#boolean"] = dial.common.enum_cyclic {
  name = "boolean",
  strlist = { "true", "false" },
}
table.insert(dial.config.searchlist.normal, "custom#boolean")

vim.api.nvim_set_keymap("n", "<C-a>", "<Plug>(dial-increment)", {})
vim.api.nvim_set_keymap("n", "<C-x>", "<Plug>(dial-decrement)", {})
