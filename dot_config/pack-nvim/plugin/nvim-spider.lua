vim.pack.add({ { src = gh("chrisgrieser/nvim-spider") } })

require("spider").setup({
  skipInsignificantPunctuation = false,
})

local set = _G.set

set({ "n", "o", "x" }, "w", "<cmd>lua require('spider').motion('w')<CR>", { desc = "[count] words forward (subword)" })
set(
  { "n", "o", "x" },
  "e",
  "<cmd>lua require('spider').motion('e')<CR>",
  { desc = "Forward to end of word [count] (subword)" }
)
set({ "n", "o", "x" }, "b", "<cmd>lua require('spider').motion('b')<CR>", { desc = "[count] words backward (subword)" })
