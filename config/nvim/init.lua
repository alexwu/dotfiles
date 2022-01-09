vim.g.do_filetype_lua = 1
vim.g.did_load_filetypes = 0

require "impatient"
require "options"
require "mappings"
require "globals"
require "plugins"

require("snazzy").setup "dark"

require "plugins.treesitter"
