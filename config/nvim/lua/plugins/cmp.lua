local cmp = require "cmp"
local lspkind = require "lspkind"
local luasnip = require "luasnip"

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0
    and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s"
      == nil
end

cmp.setup {
  sources = {
    { name = "luasnip" },
    { name = "treesitter" },
    { name = "nvim_lsp" },
    { name = "nvim_lua" },
    { name = "cmp_tabnine" },
    { name = "path" },
  },
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.close(),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if vim.fn.pumvisible() == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, true, true), "n", true)
      elseif has_words_before() and luasnip.expand_or_jumpable() then
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true),
          "",
          true
        )
      else
        fallback()
      end
    end, {
      "i",
      "s",
    }),
    ["<S-Tab>"] = cmp.mapping(function()
      if vim.fn.pumvisible() == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, true, true), "n", true)
      elseif luasnip.jumpable(-1) then
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true),
          "",
          true
        )
      end
    end, {
      "i",
      "s",
    }),
  },
  preselect = cmp.PreselectMode.None,
  formatting = {
    format = function(entry, vim_item)
      vim_item.kind = lspkind.presets.default[vim_item.kind] .. " " .. vim_item.kind
      vim_item.menu = ({
        buffer = "[Buffer]",
        nvim_lsp = "[LSP]",
        nvim_lua = "[Lua]",
        cmp_tabnine = "[TN]",
        path = "[Path]",
        luasnip = "[LuaSnip]",
        treesitter = "[Treesitter]",
      })[entry.source.name]

      vim_item.dup = ({
        buffer = 0,
        path = 0,
        nvim_lsp = 0,
        cmp_tabnine = 0,
        nvim_lua = 0,
        treesitter = 0,
      })[entry.source.name] or 0
      return vim_item
    end,
  },
  documentation = { border = "rounded" },
}
