return {
  {
    "neovim/nvim-lspconfig",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    config = function()
      vim.lsp.config("vtsls", {
        root_markers = { "tsconfig.json", "jsconfig.json" },
        settings = {
          typescript = {
            inlayHints = {
              parameterNames = { enabled = "literals" },
              parameterTypes = { enabled = true },
              variableTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              enumMemberValues = { enabled = true },
            },
            suggest = { completeFunctionCalls = true },
          },
          vtsls = {
            experimental = {
              completion = { enableServerSideFuzzyMatch = true },
            },
          },
        },
      })
      vim.lsp.enable("vtsls")

      vim.lsp.config("denols", {
        root_markers = { "deno.json", "deno.jsonc" },
      })
      vim.lsp.enable("denols")

      vim.lsp.config("biome", {
        filetypes = { "typescript", "typescriptreact" },
      })
      vim.lsp.enable("biome")
    end,
  },
}
