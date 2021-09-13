local lspconfig = require "lspconfig"
local root_pattern = lspconfig.util.root_pattern
local lsp_installer = require "nvim-lsp-installer"
local on_attach = require("plugins.lsp.defaults").on_attach
local nnoremap = require("astronauta.keymap").nnoremap

local installed_servers = lsp_installer.get_installed_servers()

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)
capabilities.textDocument.completion.completionItem.snippetSupport = true

for _, server in pairs(installed_servers) do
  local opts = {on_attach = on_attach, capabilities = capabilities}

  if server.name == "sumneko_lua" then
    opts.settings = {
      Lua = {diagnostics = {globals = {"vim", "use", "use_rocks"}}}
    }
  end

  if server.name == "tsserver" then
    opts.on_attach = function(client, bufnr)
      client.resolved_capabilities.document_formatting = false
      client.resolved_capabilities.document_range_formatting = false

      on_attach(client, bufnr)

      require("null-ls").config {}
      require("lspconfig")["null-ls"].setup {
        root_dir = root_pattern(".eslintrc.js"),
        autostart = false
      }
      local ts_utils = require("nvim-lsp-ts-utils")

      ts_utils.setup {
        disable_commands = false,
        enable_import_on_completion = true,
        import_on_completion_timeout = 5000,
        eslint_bin = "eslint_d",
        eslint_enable_diagnostics = true,
        eslint_opts = {diagnostics_format = "#{m} [#{c}]"},
        enable_formatting = true,
        formatter = "eslint_d",
        filter_out_diagnostics_by_code = {80001}
      }

      ts_utils.setup_client(client)

      nnoremap {
        "<Leader>y",
        function() vim.lsp.buf.formatting() end,
        silent = true,
        buffer = true
      }
      nnoremap {
        "<Leader>o",
        ts_utils.organize_imports,
        silent = true,
        buffer = true
      }
    end
    opts.filetypes = {"typescript", "typescriptreact", "typescript.tsx"}
  end

  if server.name == "graphql" then
    opts.filetypes = {"graphql"}
    opts.root_dir = root_pattern(".git", ".graphqlrc")
  end
  if server.name == "jsonls" then opts.filetypes = {"json"} end

  server:setup(opts)
end

local rubocop = {
  lintCommand = "bundle exec rubocop --force-exclusion --stdin ${INPUT}",
  lintStdin = true,
  lintFormats = {"%f:%l:%c: %m"},
  lintIgnoreExitCode = true,
  formatCommand = "bundle exec rubocop -A -f quiet --stderr -s ${INPUT}",
  formatStdin = true
}

lspconfig.efm.setup {
  init_options = {
    documentFormatting = true,
    codeAction = true,
    completion = true,
    hover = true,
    documentSymbol = true
  },
  filetypes = {"ruby", "eruby"},
  root_dir = function(fname)
    return lspconfig.util.root_pattern("tsconfig.json")(fname) or
             lspconfig.util.root_pattern(".eslintrc.js", ".git")(fname);
  end,
  settings = {
    rootMarkers = {".eslintrc.js", ".git/", "Gemfile"},
    languages = {
      javascript = {},
      typescript = {},
      javascriptreact = {},
      typescriptreact = {},
      ruby = {rubocop}
    }
  },
  on_attach = on_attach,
  capabilities = capabilities
}

--[[ lspconfig.graphql.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {"graphql-lsp", "server", "-m", "stream"},
  filetypes = {"graphql"},
<<<<<<< Updated upstream
=======
  root_dir = lspconfig.util.root_pattern(".git", ".graphqlrc")
>>>>>>> Stashed changes
}
 ]]
lspconfig.sorbet.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {
    "bundle", "exec", "srb", "tc", "--lsp", "--enable-all-beta-lsp-features"
  },
  rootMarkers = {".git/", "Gemfile", "sorbet"}
}

lspconfig.rust_analyzer.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      assist = {importGranularity = "module", importPrefix = "by_self"},
      cargo = {loadOutDirsFromCheck = true},
      procMacro = {enable = true}
    }
  }
}
