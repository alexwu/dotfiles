local saga = require('lspsaga')
local utils = require('utils')
local map = utils.map

-- add your config value here
-- default value
-- use_saga_diagnostic_sign = true
-- error_sign = '',
-- warn_sign = '',
-- hint_sign = '',
-- infor_sign = '',
-- error_header = "  Error",
-- warn_header = "  Warn",
-- hint_header = "  Hint",
-- infor_header = "  Infor",
-- max_diag_msg_width = 50,
-- code_action_icon = ' ',
-- code_action_keys = { quit = 'q',exec = '<CR>' }
-- finder_definition_icon = '  ',
-- finder_reference_icon = '  ',
-- max_finder_preview_lines = 10,
-- finder_action_keys = {
--   open = 'o', vsplit = 's',split = 'i',quit = 'q',scroll_down = '<C-f>', scroll_up = '<C-b>' -- quit can be a table
-- },
-- code_action_keys = {
--   quit = 'q',exec = '<CR>'
-- },
-- rename_action_keys = {
--   quit = '<C-c>',exec = '<CR>'  -- quit can be a table
-- },
-- definition_preview_icon = '  '
-- 1: thin border | 2: rounded border | 3: thick border | 4: ascii border
-- border_style = 1
-- rename_prompt_prefix = '➤',
-- if you don't use nvim-lspconfig you must pass your server name and
-- the related filetypes into this table
-- like server_filetype_map = {metals = {'sbt', 'scala'}}
-- server_filetype_map = {}

saga.init_lsp_saga {
  use_saga_diagnostic_sign = true,
  error_sign = '✘',
  warn_sign = '>>',
  infor_sign = '♦',
  border_style = 2,
  finder_action_keys = {
    open = '<CR>', vsplit = 's',split = 'i',quit = 'q',scroll_down = '<C-f>', scroll_up = '<C-b>' -- quit can be a table
  },
  code_action_keys = {
    quit = '<Esc>',exec = '<CR>'
  },
  rename_action_keys = {
    quit = '<Esc>',exec = '<CR>'  -- quit can be a table
  },
}

-- saga.init_lsp_saga()

map("n", "K", "<cmd>lua require('lspsaga.hover').render_hover_doc()<CR>", { silent = true })
map("n", "<leader>aa", "<cmd>lua require('lspsaga.codeaction').code_action()<CR>", { silent = true })
map("v", "<leader>a", "<cmd>'<,'>lua require('lspsaga.codeaction').range_code_action()<CR>", { silent = true })
map("n", "gd", "<cmd>lua require('lspsaga.provider').lsp_finder()<CR>", { silent = true })
map("n", "<leader>n", "<cmd>lua require('lspsaga.rename').rename()<CR>", { silent = true })

