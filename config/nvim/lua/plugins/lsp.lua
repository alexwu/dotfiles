local lspconfig = require "lspconfig"

local on_attach = require("plugins.lsp.utils").default_on_attach

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

require("plugins.lsp.typescript").setup(on_attach, capabilities)
--[[
local luadev = require("lua-dev").setup({
  library = {vimruntime = true, types = true, plugins = true},
  lspconfig = {
    settings = {Lua = {diagnostics = {globals = {"vim", "use", "use_rocks"}}}},
    on_attach = on_attach,
    capabilities = capabilities
  }
})
--]]
-- lspconfig.sumneko_lua.setup(luadev)
require("null-ls").config {}
require("lspconfig")["null-ls"].setup {}
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
  on_attach = on_attach,
  capabilities = capabilities
}

lspconfig.graphql.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {"graphql-lsp", "server", "-m", "stream"},
  filetypes = {"graphql"},
  root_dir = lspconfig.util.root_pattern(".git", ".graphqlrc")
}

lspconfig.sorbet.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {
    "bundle", "exec", "srb", "tc", "--lsp", "--enable-all-beta-lsp-features"
  },
  rootMarkers = {".git/", "Gemfile", "sorbet"}
}
lspconfig.gopls.setup {on_attach = on_attach, capabilities = capabilities}

lspconfig.jsonls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = {"json"}
}

lspconfig.vimls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = {"vim"}
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
