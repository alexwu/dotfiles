local dial = require "dial"
local nmap = vim.keymap.nmap
local vmap = vim.keymap.vmap

dial.augends["custom#boolean"] = dial.common.enum_cyclic {
  name = "boolean",
  strlist = { "true", "false" },
}
dial.augends["custom#tests"] = dial.common.enum_cyclic {
  name = "tests",
  strlist = { "it", "fit", "xit" },
}
dial.augends["custom#enable"] = dial.common.enum_cyclic {
  name = "enable",
  strlist = { "enable", "disable" },
}
table.insert(dial.config.searchlist.normal, "custom#boolean")
table.insert(dial.config.searchlist.normal, "custom#tests")
table.insert(dial.config.searchlist.normal, "custom#enable")

dial.config.searchlist.visual = {
  "number#decimal",
  "number#hex",
  "number#binary",
  "date#[%Y/%m/%d]",
  "char#alph#capital#word",
}

nmap { "<C-a>", "<Plug>(dial-increment)" }
nmap { "<C-x>", "<Plug>(dial-decrement)" }

vmap { "<C-a>", "<Plug>(dial-increment)" }
vmap { "<C-x>", "<Plug>(dial-decrement)" }
