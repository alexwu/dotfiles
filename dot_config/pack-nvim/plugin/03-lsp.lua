-- nvim-lspconfig core: server defaults + diagnostic config + LspProgress + LspAttach
-- feature gating + VimEnter-deferred enables.
-- Numeric prefix forces this to load early (after 00-lush, 01-snazzy, 02-snacks) so any
-- LspAttach handlers registered by later plugin specs see the same lifecycle.

vim.pack.add({ { src = gh("neovim/nvim-lspconfig") } })

-- LspProgress → native echo + statusline redraw (port from main config plugins/lsp.lua)
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(ev)
    local value = ev.data.params.value
    vim.api.nvim_echo({ { value.message or "done" } }, false, {
      id = "lsp." .. ev.data.params.token,
      kind = "progress",
      source = "vim.lsp",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
    vim.cmd.redrawstatus()
  end,
})

-- Enable LSP features when the attached server supports them
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end

    if client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end

    if client:supports_method("textDocument/linkedEditingRange") then
      vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
    end
  end,
})

-- Server enables — defer until VimEnter so mason has a chance to install missing ones,
-- and so runtime registration races don't drop servers (notably emmylua_ls).
-- Per-server config lives in after/lsp/<name>.lua (auto-merged by Neovim).
local servers = {
  "basedpyright",
  "biome",
  "denols",
  "emmylua_ls",
  "eslint",
  "gdscript",
  "html",
  "just",
  "markdown_oxide",
  "oxlint",
  "ruby_lsp",
  "ruff",
  "sorbet",
  "sourcekit",
  "sqruff",
  "tailwindcss",
  "taplo",
  "ts_query_ls",
  "ty",
  "typos_lsp",
  "vimdoc_ls",
  "vtsls",
  "yamlls",
  "zk",
  "zls",
}

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.lsp.enable(servers)
  end,
})
