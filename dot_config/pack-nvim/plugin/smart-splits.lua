vim.pack.add({ { src = gh("mrjones2014/smart-splits.nvim") } })

require("smart-splits").setup({})

local set = _G.set
set("n", "<C-h>", require("smart-splits").move_cursor_left)
set("n", "<C-j>", require("smart-splits").move_cursor_down)
set("n", "<C-k>", require("smart-splits").move_cursor_up)
set("n", "<C-l>", require("smart-splits").move_cursor_right)
