local M = {}
local action_state = require "telescope.actions.state"

M.clear_line = function(prompt_bufnr)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:reset_prompt()
end

return M
