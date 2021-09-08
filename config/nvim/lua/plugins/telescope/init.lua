local nnoremap = require("astronauta.keymap").nnoremap
local actions = require("telescope.actions")

R = function(name)
  require("plenary.reload").reload_module(name)
  return require(name)
end

require("telescope").setup {
  defaults = {
    set_env = {["COLORTERM"] = "truecolor"},
    prompt_prefix = "❯ ",
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-h>"] = R("telescope").extensions.hop.hop,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-u>"] = require("plugins.telescope.actions").clear_line
      }
    }
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = false,
      override_file_sorter = true,
      case_mode = "smart_case"
    },
    hop = {
      keys = {"a", "s", "d", "f", "g", "h", "j", "k", "l", ";"},
      sign_hl = {"HopNextKey"},
      line_hl = {"HopNextKey"},
      clear_selection_hl = false,
      trace_entry = true,
      reset_selection = true
    },
    frecency = {
      workspaces = {
        ["dotfiles"] = "~/.dotfiles",
        ["editorder"] = "~/Code/editorder",
      }
    }
  }
}
require("telescope").load_extension("fzf")
require("telescope").load_extension("frecency")
require("telescope").load_extension("hop")
require("telescope").load_extension("gh")

nnoremap {"<Leader>f", function() require("telescope.builtin").fd() end}

nnoremap {
  "<Leader>t",
  function() require("telescope").extensions.frecency.frecency() end
}

nnoremap {"<Leader>rg", function() require("telescope.builtin").live_grep() end}
nnoremap {"<Leader>ag", function() require("telescope.builtin").live_grep() end}
nnoremap {
  "<Leader>a", function() require("telescope.builtin").lsp_code_actions() end
}
nnoremap {
  "<Leader>/",
  function() require("telescope.builtin").current_buffer_fuzzy_find() end
}
nnoremap {
  "<Leader>br", function() require("telescope.builtin").git_branches() end
}
nnoremap {"<Leader>st", function() require("telescope.builtin").git_stash() end}

vim.cmd [[ autocmd FileType TelescopePrompt setlocal nocursorline ]]
