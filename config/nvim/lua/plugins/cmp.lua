local cmp = require("cmp")
local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local shift_tab = function(fallback)
  if vim.fn.pumvisible() == 1 then
    return t "<C-p>"
  elseif vim.fn.call("vsnip#jumpable", {-1}) == 1 then
    return t "<Plug>(vsnip-jump-prev)"
  else
    fallback()
  end
end
cmp.setup {
  sources = {
    {name = "path"}, {name = "buffer"}, {name = "vsnip"}, {name = "emoji"},
    {name = "nvim_lsp"}, {name = "nvim_lua"}
  },
  snippet = {expand = function(args) vim.fn["vsnip#anonymous"](args.body) end},
  mapping = {
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.close(),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true
    }),
    ["<Tab>"] = function(fallback)
      if vim.fn.pumvisible() == 1 then
        vim.fn.feedkeys(vim.api
                          .nvim_replace_termcodes("<C-n>", true, true, true),
                        "n")
      elseif vim.fn["vsnip#available"]() == 1 then
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes(
                          "<Plug>(vsnip-expand-or-jump)", true, true, true), "")
      else
        fallback()
      end
    end,
    ["<S-Tab>"] = shift_tab
  },
  preselect = cmp.PreselectMode.None
}