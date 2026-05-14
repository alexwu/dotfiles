vim.pack.add({
  { src = gh("mrcjkb/rustaceanvim"), version = vim.version.range("^9") },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("bombeelu.rust_keymaps", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name ~= "rust_analyzer" then
      return
    end

    local bufnr = ev.buf

    vim.keymap.set("n", "K", function()
      vim.cmd.RustLsp({ "hover", "actions" })
    end, { buffer = bufnr, desc = "Rust: hover actions" })

    vim.keymap.set("n", "gra", function()
      vim.cmd.RustLsp("codeAction")
    end, { buffer = bufnr, desc = "Rust: code action" })
  end,
})
