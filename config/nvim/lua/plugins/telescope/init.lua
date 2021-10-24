local nnoremap = vim.keymap.nnoremap
local actions = require "telescope.actions"
local builtin = require "telescope.builtin"

R = function(name)
  require("plenary.reload").reload_module(name)
  return require(name)
end

require("telescope").setup {
  defaults = {
    set_env = { ["COLORTERM"] = "truecolor" },
    prompt_prefix = "❯ ",
    preview = false,
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-h>"] = R("telescope").extensions.hop.hop,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-u>"] = require("plugins.telescope.actions").clear_line,
      },
    },
    theme = "dropdown",
  },
  pickers = {
    file_browser = {},
    find_files = {},
    buffers = {
      initial_mode = "normal",
      mappings = {
        n = {
          ["<leader><space>"] = actions.close,
        },
      },
    },
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
  },
}
require("telescope").load_extension "fzf"
require("telescope").load_extension "hop"

nnoremap {
  "<Leader><space>",
  function()
    builtin.buffers()
  end,
}
nnoremap {
  "<Leader>f",
  function()
    builtin.find_files(require("telescope.themes").get_dropdown {
      layout_config = {
        width = function()
          return math.max(100, vim.fn.round(vim.o.columns * 0.3))
        end,
      },
    })
  end,
}

nnoremap {
  "<Leader>t",
  function()
    builtin.treesitter()
  end,
}

nnoremap {
  "<Leader>rg",
  function()
    builtin.live_grep()
  end,
}
nnoremap {
  "<Leader>br",
  function()
    builtin.git_branches()
  end,
}
nnoremap {
  "<Leader>st",
  function()
    builtin.git_stash()
  end,
}

nnoremap {
  "<Leader>i",
  function()
    require("plugins.telescope.pickers").related_files()
  end,
}

vim.cmd [[autocmd FileType TelescopePrompt setlocal nocursorline]]
vim.cmd [[autocmd User TelescopePreviewerLoaded setlocal wrap]]
