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
    layout_config = {
      width = function()
        return math.max(100, vim.fn.round(vim.o.columns * 0.3))
      end,
    },
    winblend = 30,
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-h>"] = R("telescope").extensions.hop.hop,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-u>"] = require("plugins.telescope.actions").clear_line,
      },
      n = {
        ["<C-h>"] = R("telescope").extensions.hop.hop,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
      },
    },
    theme = "dropdown",
  },
  pickers = {
    builtin = {
      theme = "dropdown",
    },
    file_browser = {},
    find_files = {
      find_command = {
        "fd",
        "--type",
        "f",
        "-uu",
        "--follow",
        "--exclude",
        ".git",
        "--exclude",
        "node_modules",
        "--exclude",
        "coverage",
        "--exclude",
        ".DS_Store",
        "--exclude",
        "*.cache",
        "--exclude",
        "*.chunk.js.map",
        "--exclude",
        "tmp",
      },
    },
    git_files = {
      theme = "dropdown",
      layout_config = {
        width = function()
          return math.max(100, vim.fn.round(vim.o.columns * 0.3))
        end,
      },
    },
    live_grep = {
      theme = "dropdown",
      vimgrep_arguments = {
        "ag",
        "--nocolor",
        "--no-heading",
        "--filename",
        "--numbers",
        "--column",
        "--smart-case",
      },
    },
    buffers = {
      initial_mode = "normal",
      theme = "dropdown",
      ignore_current_buffer = true,
      sort_lastused = true,
      layout_config = {
        width = function()
          return math.max(100, vim.fn.round(vim.o.columns * 0.3))
        end,
      },
      path_display = { "smart" },
      mappings = {
        n = {
          ["<leader><space>"] = actions.close,
        },
      },
    },
    lsp_references = {
      theme = "dropdown",
      initial_mode = "normal",
    },
    lsp_definitions = {
      theme = "dropdown",
      initial_mode = "normal",
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
    frecency = {
      show_scores = false,
      show_unindexed = true,
      ignore_patterns = { "*.git/*", "*/tmp/*" },
      disable_devicons = false,
      workspaces = {
        ["eo"] = vim.fn.expand "~/Code/cleverific/editorder/",
        ["admin"] = vim.fn.expand "~/Code/cleverific/editorder-admin/",
        ["oracle"] = vim.fn.expand "~/Code/cleverific/oracle/",
        ["dot"] = vim.fn.expand "~/.dotfiles",
      },
    },
    dash = {
      theme = "dropdown",
    },
    termfinder = {
      theme = "dropdown",
    },
  },
}
require("telescope").load_extension "fzf"
require("telescope").load_extension "hop"
require("telescope").load_extension "frecency"
require("telescope").load_extension "zoxide"
require("telescope").load_extension "termfinder"

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
  "<Leader>g",
  function()
    builtin.git_files()
  end,
}

nnoremap {
  "<Leader>t",
  function()
    builtin.builtin { include_extensions = true }
  end,
}

nnoremap {
  "<Leader>rg",
  function()
    builtin.live_grep()
  end,
}
nnoremap {
  "<Leader>ag",
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
  "<Leader>sn",
  function()
    require("plugins.telescope.pickers").snippets()
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
