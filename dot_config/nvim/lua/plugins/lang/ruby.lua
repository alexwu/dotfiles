return {
  {
    "neovim/nvim-lspconfig",
    ft = { "ruby", "eruby" },
    config = function()
      vim.lsp.config("ruby_lsp", {
        init_options = {
          enabledFeatures = {
            diagnostics = true,
            formatting = false,
          },
        },
      })
      vim.lsp.enable("ruby_lsp")

      vim.lsp.config("sorbet", {
        cmd = { "bundle", "exec", "srb", "typecheck", "--lsp" },
        root_markers = { "sorbet/config" },
      })
      vim.lsp.enable("sorbet")
    end,
  },
}
