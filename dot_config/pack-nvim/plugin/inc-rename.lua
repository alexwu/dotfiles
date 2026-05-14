vim.pack.add({ { src = gh("smjonas/inc-rename.nvim") } })

require("inc_rename").setup({
  input_buffer_type = "snacks",
})

_G.set("n", "grn", function()
  return ":IncRename " .. vim.fn.expand("<cword>")
end, { expr = true, desc = "Rename symbol" })
