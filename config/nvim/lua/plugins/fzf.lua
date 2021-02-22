local utils = require("utils")
local map = utils.map

-- FZF because telescope is actually garbage
-- vim.g.fzf_colors["fg+"] = { "bg", "CursorLine" }
-- vim.g.fzf_colors["bg+"] = { "bg", "CursorLine", "CursorColumn" }
-- vim.g.fzf_colors["hl+"] = { "fg", "Statement" }
map("n", "<C-p>", "<cmd>Files<cr>")
