local lspconfig = require "lspconfig"
local saga = require "lspsaga"

saga.init_lsp_saga {
  use_saga_diagnostic_sign = true,
  error_sign = "✘",
  warn_sign = "⚠",
  hint_sign = "♦",
  infor_sign = "♦",
  border_style = 2
  -- dianostic_header_icon = '   ',
  -- code_action_icon = ' ',
  -- code_action_keys = { quit = 'q',exec = '<CR>' }
  -- finder_definition_icon = '  ',
  -- finder_reference_icon = '  ',
  -- finder_action_keys = {
  --   open = 'o', vsplit = 's',split = 'i',quit = 'q',scroll_down = '<C-f>', scroll_up = '<C-b>' -- quit can be a table
  -- },
  -- code_action_keys = {
  --   quit = 'q',exec = '<CR>'
  -- },
  -- rename_action_keys = {
  --   quit = '<C-c>',exec = '<CR>'  -- quit can be a table
  -- },
  -- definition_preview_icon = '  '
  -- rename_prompt_prefix = '➤',

}

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

local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  local opts = {noremap = true, silent = true}
  buf_set_keymap("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  buf_set_keymap("n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", opts)
  buf_set_keymap("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>",
                 opts)
  buf_set_keymap("v", "<leader>a",
                 "<cmd>'<,'>lua require(lua vim.lsp.buf.range_code_action()<CR>",
                 opts)
  buf_set_keymap("n", "K",
                 "<Cmd>lua require('lspsaga.hover').render_hover_doc()<CR>",
                 opts)
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

  vim.cmd [[ autocmd CursorHold * lua show_diagnostic_on_hold() ]]
  -- vim.cmd [[ autocmd CursorMoved * lua show_diagnostic_on_hold() ]]
  -- vim.cmd [[ autocmd CursorHold * lua require'lspsaga.diagnostic'.show_line_diagnostics() ]]
end

local in_range = function(range, pos)
  local row = pos[1] - 1
  local col = pos[2]

  if not (row == range["start"].line) or not (row == range["end"].line) then
    return false
  else
    return col >= range["start"].character and col < range["end"].character
  end
end

function _G.show_diagnostic_on_hold()
  local d = vim.lsp.diagnostic.get_line_diagnostics()
  local pos = vim.api.nvim_win_get_cursor(0)
  if not vim.tbl_isempty(d) then
    for _, item in ipairs(d) do
      local range = item.range
      if in_range(range, pos) then
        return require"lspsaga.diagnostic".show_line_diagnostics()
      end
    end
  end
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
  init_options = {
    documentFormatting = true,
    codeAction = true,
    completion = true,
    hover = true,
    documentSymbol = true
  },
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

lspconfig.graphql.setup {
  on_attach = on_attach,
  cmd = {"graphql-lsp", "server", "-m", "stream"},
  filetypes = {"graphql"},
  root_dir = lspconfig.util.root_pattern(".git", ".graphqlrc")
}

lspconfig.tsserver.setup {on_attach = on_attach}
lspconfig.sorbet.setup {
  on_attach = on_attach,
  cmd = {
    "/Users/jamesbombeelu/.bin/srb", "--lsp", "--enable-all-beta-lsp-features"
  }
}
lspconfig.vimls.setup {on_attach = on_attach}
