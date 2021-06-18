local lspconfig = require "lspconfig"
local saga = require "lspsaga"

local default_on_attach = require("plugins.lsp.utils").default_on_attach

require"lspinstall".setup()

saga.init_lsp_saga {
  use_saga_diagnostic_sign = true,
  -- error_sign = "❌",
  error_sign = "✘",
  -- warn_sign = "⚠️",
  warn_sign = "",
  -- hint_sign = "🔍",
  -- hint_sign = "",
  hint_sign = "",
  -- infor_sign = "ℹ️",
  infor_sign = "",
  border_style = "round",
  dianostic_header_icon = "📎",
  -- code_action_icon = "💡",
  code_action_icon = "",
  code_action_keys = {quit = "<esc>", exec = "<CR>"},
  code_action_prompt = {
    enable = true,
    sign = true,
    sign_priority = 20,
    virtual_text = false
  }
}

local handlers = vim.lsp.handlers
handlers["textDocument/codeAction"] =
  require"lsputil.codeAction".code_action_handler
handlers["textDocument/references"] =
  require"lsputil.locations".references_handler
handlers["textDocument/definition"] =
  require"lsputil.locations".definition_handler
handlers["textDocument/declaration"] =
  require"lsputil.locations".declaration_handler
handlers["textDocument/typeDefinition"] =
  require"lsputil.locations".typeDefinition_handler
handlers["textDocument/implementation"] =
  require"lsputil.locations".implementation_handler
handlers["textDocument/documentSymbol"] =
  require"lsputil.symbols".document_handler
handlers["workspace/symbol"] = require"lsputil.symbols".workspace_handler
handlers["textDocument/publishDiagnostics"] =
  vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics,
               {virtual_text = false, underline = true, signs = true})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

require("plugins.lsp.typescript").setup(default_on_attach, capabilities)

lspconfig.lua.setup {
  settings = {
    Lua = {
      runtime = {version = "LuaJIT", path = vim.split(package.path, ";")},
      diagnostics = {globals = {"vim", "use", "use_rocks"}},
      workspace = {
        library = {
          [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
        }
      }
    }
  },
  on_attach = default_on_attach,
  capabilities = capabilities
}

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
