require("trouble").setup {mode = "lsp_document_diagnostics"}

vim.api.nvim_set_keymap("n", "<leader>xd",
                        "<cmd>Trouble lsp_document_diagnostics<cr>",
                        {silent = true, noremap = true})
