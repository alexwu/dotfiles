local lspconfig = require'lspconfig'

-- lspconfig.tsserver.setup {
--   cmd = { "typescript-language-server", "--stdio" },
--   filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
--   root_dir = lspconfig.util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git"),
-- }

lspconfig.tsserver.setup{}
lspconfig.sorbet.setup{
  cmd = { "/Users/jamesbombeelu/.bin/sorbet", "--lsp" }
}
lspconfig.vimls.setup{}
