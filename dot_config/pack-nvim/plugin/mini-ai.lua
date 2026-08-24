vim.pack.add({
  { src = gh("nvim-mini/mini.extra") },
  { src = gh("nvim-mini/mini.ai") },
})

require("mini.extra").setup()

local ai = require("mini.ai")
ai.setup({
  n_lines = 500,
  custom_textobjects = {
    -- Make `aB` / `iB` act on around/inside whole *b*uffer
    B = MiniExtra.gen_ai_spec.buffer(),
    f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
    o = ai.gen_spec.treesitter({
      a = { "@block.outer", "@conditional.outer", "@loop.outer" },
      i = { "@block.inner", "@conditional.inner", "@loop.inner" },
    }, {}),
    t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
    d = { "%f[%d]%d+" },
    e = {
      {
        "%u[%l%d]+%f[^%l%d]",
        "%f[%S][%l%d]+%f[^%l%d]",
        "%f[%P][%l%d]+%f[^%l%d]",
        "^[%l%d]+%f[^%l%d]",
      },
      "^().*()$",
    },
    g = function()
      local from = { line = 1, col = 1 }
      local to = {
        line = vim.fn.line("$"),
        col = math.max(vim.fn.getline("$"):len(), 1),
      }
      return { from = from, to = to }
    end,
  },
})
