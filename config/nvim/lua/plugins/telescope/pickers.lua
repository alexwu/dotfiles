local M = {}
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local finders = require "telescope.finders"

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

return M
