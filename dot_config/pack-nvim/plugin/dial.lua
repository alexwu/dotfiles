vim.pack.add({ { src = gh("monaqa/dial.nvim") } })

local augend = require("dial.augend")

require("dial.config").augends:register_group({
  default = {
    augend.integer.alias.decimal,
    augend.integer.alias.decimal_int,
    augend.constant.alias.bool,
    augend.constant.new({
      elements = { "and", "or" },
      word = true,
      cyclic = true,
    }),
    augend.constant.new({
      elements = { "&&", "||" },
      word = false,
      cyclic = true,
    }),
    augend.constant.new({
      elements = { "it", "fit", "xit" },
      word = true,
      cyclic = true,
    }),
    augend.constant.new({
      elements = { "enable", "disable" },
      word = true,
      cyclic = true,
    }),
  },
  typescript = {
    augend.integer.alias.decimal,
    augend.integer.alias.hex,
    augend.constant.new({ elements = { "var", "let", "const" } }),
  },
})

local set = _G.set

set("n", "<C-a>", function()
  require("dial.map").manipulate("increment", "normal")
end, { desc = "Increment number/boolean/constant" })

set("n", "<C-x>", function()
  require("dial.map").manipulate("decrement", "normal")
end, { desc = "Decrement number/boolean/constant" })

set("v", "<C-a>", function()
  require("dial.map").manipulate("increment", "visual")
end, { desc = "Increment selection" })

set("v", "<C-x>", function()
  require("dial.map").manipulate("decrement", "visual")
end, { desc = "Decrement selection" })
