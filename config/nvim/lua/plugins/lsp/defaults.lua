local M = {}
local nnoremap = require("astronauta.keymap").nnoremap

function M.on_attach(client, bufnr)
  local signs = {
    Error = "✘ ",
    Warning = " ",
    Hint = " ",
    Information = " ",
  }

  for type, icon in pairs(signs) do
    local hl = "LspDiagnosticsSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
  end

  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
      virtual_text = false,
      underline = true,
      signs = true,
      update_in_insert = false,
    }
  )
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover,
    { border = "rounded", focusable = false }
  )

  -- local original_set_virtual_text = vim.lsp.diagnostic.set_virtual_text
  -- local set_virtual_text_custom = function(diagnostics, bufnr, client_id,
  --                                          sign_ns, opts)
  --   opts = opts or {}
  --   opts.severity_limit = "Error"
  --   original_set_virtual_text(diagnostics, bufnr, client_id, sign_ns, opts)
  -- end

  -- vim.lsp.diagnostic.set_virtual_text = set_virtual_text_custom

  nnoremap {
    "gD",
    function()
      vim.lsp.buf.declaration()
    end,
    silent = true,
  }
  nnoremap {
    "gr",
    function()
      vim.lsp.buf.references()
    end,
    silent = true,
  }
  nnoremap {
    "<Leader>a",
    function()
      vim.lsp.buf.code_action()
    end,
    silent = true,
  }
  nnoremap {
    "K",
    function()
      vim.lsp.buf.hover()
    end,
    silent = true,
  }
  nnoremap {
    "L",
    function()
      vim.lsp.diagnostic.show_line_diagnostics { border = "rounded", focusable = false }
    end,
    silent = true,
  }
  nnoremap {
    "[d",
    function()
      vim.lsp.diagnostic.goto_prev()
    end,
    silent = true,
  }
  nnoremap {
    "]d",
    function()
      vim.lsp.diagnostic.goto_next()
    end,
    silent = true,
  }
  nnoremap {
    "<BSlash>y",
    function()
      vim.lsp.buf.formatting()
    end,
    silent = true,
  }
  nnoremap {
    "<Leader>y",
    function()
      vim.lsp.buf.formatting()
    end,
    silent = true,
  }

  require("lsp_signature").on_attach {
    bind = true,
    handler_opts = { border = "rounded" },
    floating_window = true,
    hint_enable = false,
    max_height = 4,
  }

  vim.cmd [[ autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb() ]]
  vim.cmd [[ autocmd FileType qf nnoremap <buffer> <silent> <CR> <CR>:cclose<CR> ]]
end

function M.capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  return capabilities
end

return M
