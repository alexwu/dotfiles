return {
  {
    "neovim/nvim-lspconfig",
    ft = { "html", "css", "scss", "javascript", "typescript", "typescriptreact", "javascriptreact", "vue" },
    config = function()
      vim.lsp.config("eslint", {
        settings = {
          format = { enable = false },
          rulesCustomizations = { { rule = "*", severity = "warn" } },
        },
      })
      vim.lsp.enable("eslint")

      vim.lsp.config("tailwindcss", {
        settings = {
          classAttributes = { "class", "className", "class:list", "classList", "ngClass", "classes" },
        },
      })
      vim.lsp.enable("tailwindcss")

      vim.lsp.enable("html")
    end,
  },
}
