local jump_target = require "hop.jump_target"
local hop = require "hop"
local hint = require "hop.hint"
local window = require "hop.window"
local M = {}

-- TODO:
function M.hint_end_words(opts)
  opts = opts
    or {
      keys = "asdghklqwertyuiopzxcvbnmfj",
      quit_key = "<Esc>",
      perm_method = require("hop.perm").TrieBacktrackFilling,
      reverse_distribution = false,
      teasing = true,
      jump_on_sole_occurrence = true,
      case_insensitive = true,
      create_hl_autocmd = true,
      current_line_only = false,
    }

  local generator = jump_target.jump_targets_by_scanning_lines

  hop.hint_with(
    generator {
      oneshot = false,
      match = function(s)
        -- return vim.regex("\\(\\k\\|\\k\\)\\+"):match_str(s)
        -- return vim.regex("\\v(\\<|>)+"):match_str(s)
        return vim.regex("\\v(_|\\{|\\}|\\(|\\)|\"|\'\\.|\\,|\\_$|\\>)+"):match_str(s)
      end,
    },
    opts
  )
end

return M
