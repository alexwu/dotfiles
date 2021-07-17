local lspconfig = require "lspconfig"

local default_on_attach = require("plugins.lsp.utils").default_on_attach

require"lspinstall".setup()

local handlers = vim.lsp.handlers
-- handlers["textDocument/codeAction"] =
--   require"lsputil.codeAction".code_action_handler
-- handlers["textDocument/references"] =
--   require"lsputil.locations".references_handler
-- handlers["textDocument/definition"] =
--   require"lsputil.locations".definition_handler
-- handlers["textDocument/declaration"] =
--   require"lsputil.locations".declaration_handler
-- handlers["textDocument/typeDefinition"] =
--   require"lsputil.locations".typeDefinition_handler
-- handlers["textDocument/implementation"] =
--   require"lsputil.locations".implementation_handler
-- handlers["textDocument/documentSymbol"] =
--   require"lsputil.symbols".document_handler
-- handlers["workspace/symbol"] = require"lsputil.symbols".workspace_handler
handlers["textDocument/publishDiagnostics"] =
  vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics,
               {virtual_text = false, underline = true, signs = true})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

require("plugins.lsp.typescript").setup(default_on_attach, capabilities)

local luadev = require("lua-dev").setup({
  library = {
    vimruntime = true, -- runtime path
    types = true, -- full signature, docs and completion of vim.api, vim.treesitter, vim.lsp and others
    plugins = true -- installed opt or start plugins in packpath
    -- you can also specify the list of plugins to make available as a workspace library
    -- plugins = { "nvim-treesitter", "plenary.nvim", "telescope.nvim" },
  },
  -- pass any additional options that will be merged in the final lsp config
  lspconfig = {
    -- cmd = {"lua-language-server"},
    on_attach = default_on_attach,
    capabilities = capabilities
  }
})

lspconfig.lua.setup(luadev)
-- lspconfig.lua.setup {
--   settings = {
--     Lua = {
--       runtime = {version = "LuaJIT", path = vim.split(package.path, ";")},
--       diagnostics = {globals = {"vim", "use", "use_rocks"}},
--       workspace = {
--         library = {
--           [vim.fn.expand("$VIMRUNTIME/lua")] = true,
--           [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
--         }
--       }
--     }
--   },
--   on_attach = default_on_attach,
--   capabilities = capabilities
-- }

local eslint = {
  lintCommand = "eslint_d -f unix --stdin --stdin-filename ${INPUT}",
  lintStdin = true,
  lintFormats = {"%f:%l:%c: %m"},
  lintIgnoreExitCode = true,
  formatCommand = "eslint_d --fix-to-stdout --stdin --stdin-filename=${INPUT}",
  formatStdin = true
}

local rubocop = {
  lintCommand = "bundle exec rubocop --force-exclusion --stdin ${INPUT}",
  lintStdin = true,
  lintFormats = {"%f:%l:%c: %m"},
  lintIgnoreExitCode = true
}

lspconfig.efm.setup {
  init_options = {
    documentFormatting = true,
    codeAction = true,
    completion = true,
    hover = true,
    documentSymbol = true
  },
  filetypes = {"ruby", "eruby", "typescript", "typescriptreact"},
  root_dir = function(fname)
    return lspconfig.util.root_pattern("tsconfig.json")(fname) or
             lspconfig.util.root_pattern(".eslintrc.js", ".git")(fname);
  end,
  settings = {
    rootMarkers = {".eslintrc.js", ".git/", "Gemfile"},
    languages = {
      javascript = {eslint},
      typescript = {eslint},
      javascriptreact = {eslint},
      typescriptreact = {eslint},
      ruby = {rubocop}
    }
  },
  on_attach = default_on_attach,
  capabilities = capabilities
}

lspconfig.graphql.setup {
  on_attach = default_on_attach,
  capabilities = capabilities,
  cmd = {"graphql-lsp", "server", "-m", "stream"},
  filetypes = {"graphql"},
  root_dir = lspconfig.util.root_pattern(".git", ".graphqlrc")
}

lspconfig.sorbet.setup {
  on_attach = default_on_attach,
  capabilities = capabilities,
  cmd = {
    "bundle", "exec", "srb", "tc", "--lsp", "--enable-all-beta-lsp-features"
  },
  rootMarkers = {".git/", "Gemfile", "sorbet"}
}
lspconfig.go.setup {on_attach = default_on_attach, capabilities = capabilities}
lspconfig.json.setup {
  on_attach = default_on_attach,
  capabilities = capabilities,
  filetypes = {"json"}
}
lspconfig.vim.setup {
  on_attach = default_on_attach,
  capabilities = capabilities,
  filetypes = {"vim"}
}
lspconfig.rust_analyzer.setup {
  on_attach = default_on_attach,
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      assist = {importGranularity = "module", importPrefix = "by_self"},
      cargo = {loadOutDirsFromCheck = true},
      procMacro = {enable = true}
    }
  }
}
