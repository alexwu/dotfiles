local cmp = require "cmp"
local lspkind = require "lspkind"
local luasnip = require "luasnip"

local has_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
    return false
  end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0
    and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
end

cmp.setup {
  sources = {
    { name = "luasnip" },
    { name = "treesitter" },
    { name = "nvim_lsp" },
    { name = "nvim_lua" },
    { name = "cmp_tabnine" },
    { name = "buffer" },
    { name = "path" },
  },
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<C-D>"] = cmp.mapping.scroll_docs(-4),
    ["<C-F>"] = cmp.mapping.scroll_docs(4),
    ["<C-SPACE>"] = cmp.mapping.complete(),
    ["<C-E>"] = cmp.mapping.close(),
    ["<TAB>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      elseif has_words_before() then
        cmp.complete()
      else
        fallback()
      end
    end, {
      "i",
      "s",
    }),
    ["<S-TAB>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
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
