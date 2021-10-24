local M = {}
local builtin = require "telescope.builtin"
local nnoremap = vim.keymap.nnoremap

function M.on_attach(_, _)
  local signs = {
    Error = "✘ ",
    Warn = " ",
    Hint = " ",
    Info = " ",
  }

  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
  end

  --[[ vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
      virtual_text = false,
      underline = true,
      signs = true,
      update_in_insert = true,
    }
  ) ]]

  vim.diagnostic.config {
    --[[ virtual_text = {
      severity = vim.diagnostic.ERROR,
    }, ]]
    virtual_text = false,
    underline = {},
    signs = true,
    float = {
      show_header = false,
      source = "if_many",
    },
  }
  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover,
    { border = "rounded", focusable = false }
  )
  nnoremap {
    "gd",
    function()
      builtin.lsp_definitions()
    end,
  }

  nnoremap {
    "gr",
    function()
      builtin.lsp_references()
    end,
  }

  nnoremap {
    "gD",
    function()
      vim.lsp.buf.declaration()
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
      vim.diagnostic.open_float(nil, {
        scope = "line",
        show_header = false,
        source = "always",
        focusable = false,
        border = "rounded",
      })
    end,
    silent = true,
  }
  nnoremap {
    "<Leader>a",
    function()
      require("code_action_menu").open_code_action_menu()
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

  vim.cmd [[autocmd CursorHold,CursorHoldI * lua require("nvim-lightbulb").update_lightbulb()]]
  vim.cmd [[autocmd CursorHold,CursorHoldI * lua Show_cursor_diagnostics()]]
  vim.cmd [[autocmd FileType qf nnoremap <buffer> <silent> <CR> <CR>:cclose<CR>]]
  vim.cmd [[autocmd FileType LspInfo,null-ls-info nmap <buffer> q <cmd>quit<cr>]]
end

function Show_cursor_diagnostics()
  vim.diagnostic.open_float(nil, {
    scope = "cursor",
    show_header = false,
    source = "always",
    focusable = false,
    border = "rounded",
  })
end

local capabilities = function()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)
  return capabilities
end

M.capabilities = capabilities()

return M
