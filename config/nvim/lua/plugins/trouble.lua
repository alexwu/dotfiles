require("trouble").setup {}

vim.api.nvim_set_keymap("n", "<leader>xx", "<cmd>LspTroubleToggle<cr>",
                        {silent = true, noremap = true})
