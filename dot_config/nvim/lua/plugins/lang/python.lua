return {
  {
    "neovim/nvim-lspconfig",
    ft = { "python" },
    config = function()
      vim.lsp.config("basedpyright", {
        settings = {
          pyright = {
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              ignore = { "*" },
            },
          },
        },
      })
      vim.lsp.enable("basedpyright")

      vim.lsp.enable("ruff")
    end,
  },
}
