local lspconfig = require("lspconfig")

local module = {}
function module.setup(on_attach, capabilities)
  lspconfig.tsserver.setup {
    on_attach = function(client, bufnr)
      -- on_attach(client, bufnr)

      -- require("null-ls").setup {}
      local ts_utils = require("nvim-lsp-ts-utils")
      -- vim.lsp.handlers["textDocument/codeAction"] = ts_utils.code_action_handler

      ts_utils.setup {
        disable_commands = false,
        enable_import_on_completion = true,
        import_on_completion_timeout = 5000
        -- eslint_bin = "eslint_d",
        -- eslint_enable_diagnostics = true,
        -- enable_formatting = true
      }

      ts_utils.setup_client(client)

      vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>o", ":TSLspOrganize<CR>",
                                  {silent = true})
      -- vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>a",
      --                             "<cmd>lua require'nvim-lsp-ts-utils'.fix_current()<CR>",
      --                             {silent = true})
      vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ia",
                                  ":TSLspImportAll<CR>", {silent = true})
      -- vim.cmd("command -buffer Format lua vim.lsp.buf.formatting()")
    end,
    capabilities = capabilities
  }
end

return module;
