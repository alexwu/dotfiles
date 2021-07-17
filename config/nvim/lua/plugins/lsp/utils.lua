local module = {}

function module.default_on_attach(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function show_documentation() end

  local border = {
    {"╭", "FloatBorder"}, {"─", "FloatBorder"}, {"╮", "FloatBorder"},
    {"│", "FloatBorder"}, {"╯", "FloatBorder"}, {"─", "FloatBorder"},
    {"╰", "FloatBorder"}, {"│", "FloatBorder"}
  }

  vim.lsp.handlers["textDocument/hover"] =
    vim.lsp
      .with(vim.lsp.handlers.hover, {border = "rounded", focusable = false})
  vim.lsp.handlers["textDocument/signatureHelp"] =
    vim.lsp.with(vim.lsp.handlers.hover, {border = border, focusable = false})

  local opts = {noremap = false, silent = true}
  buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  buf_set_keymap("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>",
                 opts)
  buf_set_keymap("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", opts)
  buf_set_keymap("n", "L",
                 "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics({border = 'rounded'})<CR>",
                 opts)
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

  require"lsp_signature".on_attach()

  vim.cmd [[ autocmd CursorHold * lua vim.lsp.diagnostic.show_line_diagnostics({border = 'rounded', focusable = false}) ]]
end

return module;
