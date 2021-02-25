local utils = require("utils")
local map = utils.map

require("kommentary.config")

vim.api.nvim_set_keymap("n", "<Bslash><Bslash>",
                        "<Plug>kommentary_line_default", {})
vim.api.nvim_set_keymap("x", "<Bslash>", "<Plug>kommentary_visual_default", {})
