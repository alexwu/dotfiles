local lspconfig = require "lspconfig"
local util = lspconfig.util
local root_pattern = util.root_pattern
local lsp_installer = require "nvim-lsp-installer"
local on_attach = require("plugins.lsp.defaults").on_attach
local capabilities = require("plugins.lsp.defaults").capabilities

lsp_installer.settings {
  log_level = vim.log.levels.DEBUG,
}
lsp_installer.on_server_ready(function(server)
  local opts = { on_attach = on_attach, capabilities = capabilities }

  opts.settings = {
    flags = {},
  }

  if server.name == "sumneko_lua" then
    opts.settings = {
      Lua = {
        diagnostics = { globals = { "vim", "use", "use_rocks" } },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
        },
        telemetry = {
          enable = false,
        },
      },
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
        auto_inlay_hints = true,
        inlay_hints_highlight = "Comment",
      }
    end

    opts.init_options = {
      hostInfo = "neovim",
      preferences = {
        includeCompletionsForImportStatements = true,
        includeInlayParameterNameHints = "none",
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
      rulesCustomizations = { { rule = "*", severity = "warn" } },
    }
  end

  if server.name == "graphql" then
    opts.filetypes = { "graphql" }
    opts.root_dir = root_pattern(".git", ".graphqlrc")
  end

  if server.name == "jsonls" then
    opts.settings = {
      json = {
        schemas = require("schemastore").json.schemas(),
      },
    }
  end

  if server.name == "rust_analyzer" then
    require("rust-tools").setup {
      server = server:get_default_options(),
    }
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

-- lspconfig.efm.setup {
--   init_options = {
--     documentFormatting = true,
--     codeAction = true,
--     completion = true,
--     hover = true,
--     documentSymbol = true,
--   },
--   filetypes = { "ruby", "eruby" },
--   root_dir = root_pattern ".rubocop.yml",
--   settings = {
--     rootMarkers = { ".rubocop.yml" },
--     languages = {
--       ruby = { rubocop },
--     },
--   },
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }
--
lspconfig.sorbet.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "ruby" },
  cmd = {
    "bundle",
    "exec",
    "srb",
    "tc",
    "--lsp",
    "--enable-all-beta-lsp-features",
  },
  root_dir = util.root_pattern "sorbet",
}

local configs = require "lspconfig/configs"
-- configs["steep"] = {
--   default_config = {
--     cmd = { "steep", "langserver" },
--     filetypes = { "ruby" },
--     root_dir = util.root_pattern "Steepfile",
--   },
-- }

-- lspconfig["steep"].setup {
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }

configs["rubocop-lsp"] = {
  default_config = {
    cmd = { "rubocop-lsp" },
    filetypes = { "ruby" },
    root_dir = util.root_pattern ".rubocop.yml",
  },
}

lspconfig["rubocop-lsp"].setup {
  on_attach = on_attach,
  capabilities = capabilities,
}

-- vim.lsp.start_client {
--   cmd = { "steep", "langserver" },
--   filetypes = { "ruby" },
--   root_dir = find_steepfile_ancestor(vim.fn.expand "%"),
--   on_attach = on_attach,
--   capabilities = capabilities,
-- }
--
require("trouble").setup {}

vim.cmd [[autocmd FileType qf nnoremap <buffer> <silent> <CR> <CR>:cclose<CR>]]
vim.cmd [[autocmd FileType LspInfo,null-ls-info nmap <buffer> q <cmd>quit<cr>]]
