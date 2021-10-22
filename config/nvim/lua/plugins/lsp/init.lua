local lspconfig = require "lspconfig"
local root_pattern = lspconfig.util.root_pattern
local lsp_installer = require "nvim-lsp-installer"
local on_attach = require("plugins.lsp.defaults").on_attach
local capabilities = require("plugins.lsp.defaults").capabilities

require("lsp_signature").setup {
  bind = true,
  handler_opts = { border = "rounded" },
  floating_window = true,
  hint_enable = true,
  max_height = 4,
}

lsp_installer.on_server_ready(function(server)
  local opts = { on_attach = on_attach, capabilities = capabilities }

  opts.settings = {
    flags = {
      debounce_text_changes = 400,
    },
  }

  if server.name == "sumneko_lua" then
    opts.settings = {
      Lua = { diagnostics = { globals = { "vim", "use", "use_rocks" } } },
    }
  end

  if server.name == "tsserver" then
    opts.on_attach = function(client, bufnr)
      client.resolved_capabilities.document_formatting = false
      client.resolved_capabilities.document_range_formatting = false

      on_attach(client, bufnr)

      local ts_utils = require "nvim-lsp-ts-utils"

      ts_utils.setup {
        disable_commands = false,
        eslint_enable_code_actions = false,
        enable_import_on_completion = true,
        import_on_completion_timeout = 5000,
        eslint_enable_diagnostics = false,
        eslint_bin = "eslint_d",
        eslint_opts = { diagnostics_format = "#{m} [#{c}]" },
        enable_formatting = false,
        formatter = "eslint_d",
        filter_out_diagnostics_by_code = { 80001 },
      }

      require("plugins.lsp.typescript").setup()
    end

    opts.init_options = {
      hostInfo = "neovim",
      preferences = {
        includeCompletionsForImportStatements = true,
        includeInlayParameterNameHints = "literals",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    }
    opts.filetypes = { "typescript", "typescriptreact", "typescript.tsx" }
  end

  if server.name == "eslint" then
    opts.on_attach = function(client, bufnr)
      client.resolved_capabilities.document_formatting = true
      on_attach(client, bufnr)
    end
    opts.settings = {
      format = { enable = true },
    }
  end

  if server.name == "graphql" then
    opts.filetypes = { "graphql" }
    opts.root_dir = root_pattern(".git", ".graphqlrc")
  end

  if server.name == "jsonls" then
    opts.filetypes = { "json" }
  end

  server:setup(opts)
  vim.cmd [[ do User LspAttachBuffers ]]
end)

local rubocop = {
  lintCommand = "bundle exec rubocop --force-exclusion --stdin ${INPUT}",
  lintStdin = true,
  lintFormats = { "%f:%l:%c: %m" },
  lintIgnoreExitCode = true,
  formatCommand = "bundle exec rubocop -A -f quiet --stderr -s ${INPUT}",
  formatStdin = true,
}

lspconfig.efm.setup {
  init_options = {
    documentFormatting = true,
    codeAction = false,
    completion = true,
    hover = true,
    documentSymbol = true,
  },
  filetypes = { "ruby", "eruby" },
  root_dir = function(fname)
    return root_pattern "tsconfig.json"(fname) or root_pattern(".eslintrc.js", ".git")(fname)
  end,
  settings = {
    rootMarkers = { ".eslintrc.js", ".git/", "Gemfile", ".rubocop.yml" },
    languages = {
      ruby = { rubocop },
    },
  },
  on_attach = on_attach,
  capabilities = capabilities,
}

lspconfig.sorbet.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = {
    "bundle",
    "exec",
    "srb",
    "tc",
    "--lsp",
    "--enable-all-beta-lsp-features",
  },
  rootMarkers = { ".git/", "Gemfile", "sorbet" },
}

lspconfig.rust_analyzer.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      assist = { importGranularity = "module", importPrefix = "by_self" },
      cargo = { loadOutDirsFromCheck = true },
      procMacro = { enable = true },
    },
  },
}

vim.cmd [[autocmd FileType LspInfo,null-ls-info nmap <buffer> q <cmd>quit<cr>]]
