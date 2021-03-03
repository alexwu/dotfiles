local lspconfig = require "lspconfig"

vim.lsp.handlers["textDocument/codeAction"] =
  require"lsputil.codeAction".code_action_handler
vim.lsp.handlers["textDocument/references"] =
  require"lsputil.locations".references_handler
vim.lsp.handlers["textDocument/definition"] =
  require"lsputil.locations".definition_handler
vim.lsp.handlers["textDocument/declaration"] =
  require"lsputil.locations".declaration_handler
vim.lsp.handlers["textDocument/typeDefinition"] =
  require"lsputil.locations".typeDefinition_handler
vim.lsp.handlers["textDocument/implementation"] =
  require"lsputil.locations".implementation_handler
vim.lsp.handlers["textDocument/documentSymbol"] =
  require"lsputil.symbols".document_handler
vim.lsp.handlers["workspace/symbol"] =
  require"lsputil.symbols".workspace_handler
vim.lsp.handlers["textDocument/publishDiagnostics"] =
  vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics,
               {virtual_text = false, underline = true, signs = true})

vim.api.nvim_exec([[
  sign define LspDiagnosticsSignError text=✘ texthl=LspDiagnosticsSignError linehl= numhl=
  sign define LspDiagnosticsSignWarning text=W texthl=LspDiagnosticsSignWarning linehl= numhl=
  sign define LspDiagnosticsSignInformation text=♦ texthl=LspDiagnosticsSignInformation linehl= numhl=
  sign define LspDiagnosticsSignHint text=♦ texthl=LspDiagnosticsSignHint linehl= numhl=
]], false)

local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  -- buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

  -- Mappings.
  local opts = {noremap = true, silent = true}
  buf_set_keymap("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  buf_set_keymap("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
  buf_set_keymap("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>",
                 opts)
  buf_set_keymap("v", "<leader>a",
                 "<cmd>'<,'>lua require(lua vim.lsp.buf.range_code_action()<CR>",
                 opts)
  buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  buf_set_keymap("n", "H", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  buf_set_keymap("n", "<space>wa",
                 "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
  buf_set_keymap("n", "<space>wr",
                 "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
  buf_set_keymap("n", "<space>wl",
                 "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>",
                 opts)
  buf_set_keymap("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>",
                 opts)
  buf_set_keymap("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  buf_set_keymap("n", "<space>e",
                 "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", opts)
  buf_set_keymap("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
  buf_set_keymap("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
  buf_set_keymap("n", "<space>q",
                 "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)

  -- Set some keybinds conditional on server capabilities
  if client.resolved_capabilities.document_formatting then
    buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>",
                   opts)
  elseif client.resolved_capabilities.document_range_formatting then
    buf_set_keymap("n", "<space>f",
                   "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
  end

  -- Set autocommands conditional on server_capabilities
  if client.resolved_capabilities.document_highlight then
    vim.api.nvim_exec([[
      augroup lsp_document_highlight
      autocmd! * <buffer>
      autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
      autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]], false)
  end

  vim.cmd [[ autocmd CursorHold * lua vim.lsp.diagnostic.show_line_diagnostics() ]]
end

local system_name = "macOS"
local sumneko_root_path = "/Users/jamesbombeelu/Code/lua-language-server"
local sumneko_binary = sumneko_root_path .. "/bin/" .. system_name ..
                         "/lua-language-server"

lspconfig.sumneko_lua.setup {
  cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"},
  settings = {
    Lua = {
      runtime = {version = "LuaJIT", path = vim.split(package.path, ";")},
      diagnostics = {globals = {"vim", "use"}},
      workspace = {
        library = {
          [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
        }
      }
    }
  },
  on_attach = on_attach
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
  lintCommand = "bundle exec rubocop --format emacs --force-exclusion --stdin ${INPUT}",
  lintStdin = true,
  lintFormats = {"%f:%l:%c: %m"},
  lintIgnoreExitCode = true,
  formatCommand = "bundle exec rubocop --fix ${INPUT}",
  formatStdin = true
}

lspconfig.efm.setup {
  init_options = {documentFormatting = true, hover = true},
  filetypes = {
    "javascript", "javascriptreact", "typescript", "typescriptreact", "ruby",
    "eruby"
  },
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
  on_attach = on_attach
}

lspconfig.tsserver.setup {on_attach = on_attach}
lspconfig.sorbet.setup {
  on_attach = on_attach,
  cmd = {"/Users/jamesbombeelu/.bin/srb", "--lsp"}
}
lspconfig.vimls.setup {on_attach = on_attach}
