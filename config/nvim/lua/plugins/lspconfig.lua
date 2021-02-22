local lspconfig = require'lspconfig'
local saga = require('lspsaga')
local utils = require('utils')

saga.init_lsp_saga {
  use_saga_diagnostic_sign = true,
  error_sign = '✘',
  warn_sign = '>>',
  infor_sign = '♦',
  border_style = 2,
  finder_action_keys = {
    open = '<CR>', vsplit = 's',split = 'i',quit = 'q',scroll_down = '<C-f>', scroll_up = '<C-b>' -- quit can be a table
  },
  code_action_keys = {
    quit = '<Esc>',exec = '<CR>'
  },
  rename_action_keys = {
    quit = '<Esc>',exec = '<CR>'  -- quit can be a table
  },
}

local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }
  buf_set_keymap("n", "K", "<cmd>lua require('lspsaga.hover').render_hover_doc()<CR>", opts)
  buf_set_keymap("n", "<leader>aa", "<cmd>lua require('lspsaga.codeaction').code_action()<CR>", opts)
  buf_set_keymap("v", "<leader>a", "<cmd>'<,'>lua require('lspsaga.codeaction').range_code_action()<CR>", opts)
  buf_set_keymap("n", "gd", "<cmd>lua require('lspsaga.provider').lsp_finder()<CR>", opts)
  buf_set_keymap("n", "<leader>n", "<cmd>lua require('lspsaga.rename').rename()<CR>", opts)

  -- Set some keybinds conditional on server capabilities
  if client.resolved_capabilities.document_formatting then
    buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  elseif client.resolved_capabilities.document_range_formatting then
    buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
  end

  -- Set autocommands conditional on server_capabilities
  if client.resolved_capabilities.document_highlight then
    vim.api.nvim_exec([[
    hi LspReferenceRead cterm=bold ctermbg=red guibg=Gray
    hi LspReferenceText cterm=bold ctermbg=red guibg=Gray
    hi LspReferenceWrite cterm=bold ctermbg=red guibg=Gray
    augroup lsp_document_highlight
    autocmd! * <buffer>
    autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
    autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
    augroup END
      ]], false)
  end

  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
      virtual_text = false,
      underline = true,
      signs = true,
    }
  )
  vim.cmd [[autocmd CursorHold * lua require'lspsaga.diagnostic'.show_line_diagnostics()]]
  vim.cmd [[autocmd CursorHoldI * silent! lua require('lspsaga.signaturehelp').signature_help()]]
end

lspconfig.tsserver.setup { on_attach = on_attach }
lspconfig.sorbet.setup {
  on_attach = on_attach,
  cmd = { "/Users/jamesbombeelu/.bin/sorbet", "--lsp" }
}
lspconfig.vimls.setup { on_attach = on_attach }
