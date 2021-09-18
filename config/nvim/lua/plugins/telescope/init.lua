local nnoremap = require("astronauta.keymap").nnoremap
local actions = require "telescope.actions"
local path = require "plenary.path"

R = function(name)
  require("plenary.reload").reload_module(name)
  return require(name)
end

require("telescope").setup {
  defaults = {
    set_env = { ["COLORTERM"] = "truecolor" },
    prompt_prefix = "❯ ",
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-h>"] = R("telescope").extensions.hop.hop,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-u>"] = require("plugins.telescope.actions").clear_line,
      },
    },
  },
  pickers = {
    file_browser = {},
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    hop = {
      keys = { "a", "s", "d", "f", "g", "h", "j", "k", "l", ";" },
      sign_hl = { "HopNextKey" },
      line_hl = { "HopNextKey" },
      clear_selection_hl = true,
      trace_entry = true,
      reset_selection = true,
    },
    frecency = {
      workspaces = {
        ["dotfiles"] = "~/.dotfiles",
        ["editorder"] = "~/Code/editorder",
      },
    },
  },
}
require("telescope").load_extension "fzf"
require("telescope").load_extension "frecency"
require("telescope").load_extension "hop"
require("telescope").load_extension "gh"
require("telescope").load_extension "neoclip"

nnoremap {
  "<Leader>f",
  require("telescope.builtin").fd,
}

nnoremap {
  "<Leader>t",
  function()
    require("telescope.builtin").treesitter()
  end,
}

nnoremap {
  "<Leader>rg",
  function()
    require("telescope.builtin").live_grep()
  end,
}
nnoremap {
  "<Leader>br",
  function()
    require("telescope.builtin").git_branches()
  end,
}
nnoremap {
  "<Leader>st",
  function()
    require("telescope.builtin").git_stash()
  end,
}

nnoremap {
  "<Leader>p",
  function()
    require("telescope").extensions.neoclip.default()
  end,
}

nnoremap {
  "<Leader>b",
  function()
    local cwd = path.new "%"
    for root, value in ipairs(vim.fn["projectionist#query"] "wrap") do
      print(root)
      print(value)
    end
  end,
}

vim.cmd [[autocmd FileType TelescopePrompt setlocal nocursorline]]
vim.cmd [[autocmd User TelescopePreviewerLoaded setlocal wrap]]
