-- Based off of: https://github.com/nvim-telescope/telescope-fzf-writer.nvim
local Job = require("plenary.job")

local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")

local minimum_grep_characters = 2
local minimum_files_characters = 0

local use_highlighter = false

return require("telescope").register_extension {
  setup = function(user_conf)
    if user_conf.minimum_grep_characters then
      minimum_grep_characters = user_conf.minimum_grep_characters
    end

    if user_conf.minimum_files_characters then
      minimum_files_characters = user_conf.minimum_files_characters
    end

    if user_conf.use_highlighter ~= nil then
      use_highlighter = user_conf.use_highlighter
    end
  end,

  exports = {
    files = function(opts)
      opts = opts or {}

      local _ = make_entry.gen_from_vimgrep(opts)
      local live_grepper = finders._new {
        fn_command = function(self, prompt)
          if #prompt < minimum_files_characters then return nil end

          return {
            writer = Job:new{
              command = "fd",
              args = {"--type f --hidden --follow"}
            },

            command = "fzf",
            args = {"--filter", prompt}
          }
        end,

        entry_maker = make_entry.gen_from_file(opts)
      }

      pickers.new(opts, {
        prompt_title = "FZF: Files",
        finder = live_grepper,
        previewer = conf.grep_previewer(opts),
        sorter = use_highlighter and sorters.highlighter_only(opts)
      }):find()
    end
  }
}
