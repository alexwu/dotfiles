local M = {}
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local custom_actions = require("plugins.telescope.actions")

M.project_files = function()
  local opts = {}
  local ok = pcall(require("telescope.builtin").git_files, opts)
  if not ok then
    require("telescope.builtin").find_files(opts)
  end
end

M.related_files = function()
  pickers.new({
    results_title = "Related Files",
    finder = require("plugins.telescope.finders").related_files(),
    sorter = sorters.get_fuzzy_file(),
  }):find()
end

M.snippets = function()
  pickers.new({
    results_title = "Snippets",
    finder = require("plugins.telescope.finders").luasnip(),
    sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
    attach_mappings = function(_, map)
      actions.select_default:replace(custom_actions.expand_snippet)
      return true
    end,
  }):find()
end

return M
