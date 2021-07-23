local lspconfig = require "lspconfig"

local default_on_attach = require("plugins.lsp.utils").default_on_attach

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

require("plugins.lsp.typescript").setup(default_on_attach, capabilities)

local luadev = require("lua-dev").setup({
  library = {vimruntime = true, types = true, plugins = true},
  lspconfig = {
    settings = {Lua = {diagnostics = {globals = {"vim", "use", "use_rocks"}}}},
    on_attach = default_on_attach,
    capabilities = capabilities
  }
})
-- lspconfig.lua.setup(luadev)

--[[ require"navigator".setup({
  debug = false,
  code_action_icon = " ",
  width = 0.75,
  height = 0.3,
  preview_height = 0.35,
  border = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"},
  on_attach = default_on_attach,
  default_mapping = true,
  keymaps = {
    {key = "gr", func = "references()"},
    {key = "gi", func = "implementation()"},
    {key = "gs", func = "signature_help()"},
    {key = "g0", func = "document_symbol()"},
    {key = "gW", func = "workspace_symbol()"},
    {key = "gD", func = "declaration({ popup_opts = { border = 'single' }})"},
    {key = "gp", func = "require('navigator.definition').definition_preview()"},
    {key = "GT", func = "require('navigator.treesitter').bufs_ts()"},
    -- {key = "<Leader>a", mode = "n", func = "code_action()"},
    {key = "<Space>D", func = "type_definition()"}, {
      key = "]d",
      func = "diagnostic.goto_next({ popup_opts = { border = single }})"
    }, {
      key = "[d",
      func = "diagnostic.goto_next({ popup_opts = { border = single }})"
    }, {key = "]r", func = "require('navigator.treesitter').goto_next_usage()"},
    {key = "[r", func = "require('navigator.treesitter').goto_previous_usage()"},
    {key = "<C-LeftMouse>", func = "definition()"},
    {key = "g<LeftMouse>", func = "implementation()"}
  },
  treesitter_analysis = true,
  code_action_prompt = {
    enable = true,
    sign = true,
    sign_priority = 40,
    virtual_text = false
  },
  icons = {
    -- Code action
    code_action_icon = " ",
    -- Diagnostics
    diagnostic_head = "🐛",
    diagnostic_head_severity_1 = "🈲"
  },
  lsp = {
    format_on_save = false,
    tsserver = {
      on_attach = function(client, bufnr)

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

        vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>o",
                                    ":TSLspOrganize<CR>", {silent = true})
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ia",
                                    ":TSLspImportAll<CR>", {silent = true})
      end,
      capabilities = capabilities
    }
  }
})
 ]]
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
-- lspconfig.go.setup {on_attach = default_on_attach, capabilities = capabilities}
-- lspconfig.json.setup {
--  on_attach = default_on_attach,
--  capabilities = capabilities,
--  filetypes = {"json"}
-- }
-- lspconfig.vim.setup {
--  on_attach = default_on_attach,
--  capabilities = capabilities,
--  filetypes = {"vim"}
-- }
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
