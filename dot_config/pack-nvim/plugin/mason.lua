-- mason + mason-lspconfig only.
-- nvim-lspconfig lives in plugin/03-lsp.lua so the LSP core (servers, autocmds) loads
-- with a numeric prefix before letter-named plugin specs that may register LspAttach
-- handlers.

vim.pack.add({
  { src = gh("williamboman/mason.nvim") },
  { src = gh("williamboman/mason-lspconfig.nvim") },
})

require("mason").setup({})

require("mason-lspconfig").setup({
  automatic_enable = {
    exclude = {
      "harper-ls",
      "harper_ls",
      "lua_ls",
      "lua-language-server",
    },
  },
})
