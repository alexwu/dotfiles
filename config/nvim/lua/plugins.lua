local execute = vim.api.nvim_command
local fn = vim.fn
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  execute("!git clone https://github.com/wbthomason/packer.nvim " ..
            install_path)
  execute "packadd packer.nvim"
end

vim.cmd([[autocmd BufWritePost plugins.lua source <afile> | PackerCompile]])

return require("packer").startup({
  function()
    use {"wbthomason/packer.nvim"}
    use {"tjdevries/astronauta.nvim"}
    use {"~/Code/nvim-snazzy"}

    use {
      "neovim/nvim-lspconfig",
      config = function() require("plugins.lsp") end
    }

    use {"nvim-treesitter/nvim-treesitter", run = ":TSUpdate"}
    use {"nvim-treesitter/nvim-treesitter-refactor"}
    use {"nvim-treesitter/nvim-treesitter-textobjects"}
    use {
      "nvim-treesitter/playground",
      opt = true,
      cmd = "TSHighlightCapturesUnderCursor"
    }
    use {"windwp/nvim-autopairs"}
    use {"windwp/nvim-ts-autotag"}
    use {"JoosepAlviste/nvim-ts-context-commentstring"}
    use {"andymass/vim-matchup"}

    use {
      "kyazdani42/nvim-web-devicons",
      config = function()
        require"nvim-web-devicons".setup {
          override = {ruby = {color = "#ff5c57"}}
        }
      end
    }

    use {"kosayoda/nvim-lightbulb"}

    use {
      "antoinemadec/FixCursorHold.nvim",
      config = function() vim.g.curshold_updatime = 250 end
    }

    use {"williamboman/nvim-lsp-installer"}
    use {
      "folke/lsp-trouble.nvim",
      requires = "kyazdani42/nvim-web-devicons",
      config = function() require("plugins.trouble") end,
      cmd = {"Trouble", "TroubleToggle"}
    }
    use {"ray-x/lsp_signature.nvim"}

    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = {"jose-elias-alvarez/null-ls.nvim"},
      ft = {
        "javascript", "javascriptreact", "typescript", "typescriptreact",
        "typescript.tsx"
      }
    }
    use {"mfussenegger/nvim-lint"}

    use {
      "ms-jpq/coq_nvim",
      disable = true,
      branch = "coq",
      run = ":COQdeps",
      config = function()
        vim.g.coq_settings = {
          auto_start = true,
          ["keymap.jump_to_mark"] = "<A-h>",
          ["clients.tabnine.enabled"] = true
        }
      end
    }
    use {
      "ms-jpq/coq.artifacts",
      disable = true,
      branch = "artifacts",
      after = "coq_nvim"
    }

    use {"simrat39/rust-tools.nvim", ft = {"rust"}}

    use {
      "nvim-telescope/telescope.nvim",
      requires = {
        {"nvim-lua/popup.nvim"}, {"nvim-lua/plenary.nvim"},
        {"nvim-telescope/telescope-fzf-native.nvim", run = "make"},
        {"kyazdani42/nvim-web-devicons"},
        {"nvim-telescope/telescope-frecency.nvim", requires = "tami5/sql.nvim"},
        {"nvim-telescope/telescope-hop.nvim"}
      },
      config = function() require("plugins.telescope") end
    }

    use {
      "sudormrfbin/cheatsheet.nvim",
      requires = {
        {"nvim-telescope/telescope.nvim"}, {"nvim-lua/popup.nvim"},
        {"nvim-lua/plenary.nvim"}
      },
      config = function() require("cheatsheet").setup() end
    }

    use {
      "beauwilliams/focus.nvim",
      config = function()
        local focus = require("focus")
        focus.enable = true

      end
    }

    use {
      "ibhagwan/fzf-lua",
      requires = {"kyazdani42/nvim-web-devicons", "vijaymarupudi/nvim-fzf"},
      cmd = {"FzfLua", "Fzf"},
      config = function() require("plugins.fzf") end,
      disable = true
    }

    use {
      "voldikss/vim-floaterm",
      config = function() require("plugins.floaterm") end
    }
    use {
      "vim-test/vim-test",
      config = function() require("plugins.vim-test") end
    }

    use {
      "kyazdani42/nvim-tree.lua",
      requires = {"kyazdani42/nvim-web-devicons"},
      config = function() require("plugins.tree") end
    }
    use {
      "hrsh7th/nvim-compe",
      requires = {"onsails/lspkind-nvim"},
      config = function() require("plugins.compe") end
    }
    use {
      "tzachar/compe-tabnine",
      run = "./install.sh",
      after = "nvim-compe",
      event = "InsertEnter"
    }
    use {
      "folke/todo-comments.nvim",
      config = function() require("plugins.todo-comments") end
    }
    use {
      "hoob3rt/lualine.nvim",
      requires = {"kyazdani42/nvim-web-devicons"},
      config = function() require("statusline") end
    }
    use {
      "norcalli/nvim-colorizer.lua",
      config = function() require("colorizer").setup() end,
      cmd = {"ColorizerToggle"}
    }
    use {
      "lewis6991/gitsigns.nvim",
      requires = {"nvim-lua/plenary.nvim"},
      config = function() require("plugins.gitsigns") end
    }
    use {
      "mhartington/formatter.nvim",
      config = function() require("plugins.formatter") end
    }
    use {"ggandor/lightspeed.nvim"}
    use {
      "monaqa/dial.nvim",
      config = function()
        vim.api.nvim_set_keymap("n", "<C-a>", "<Plug>(dial-increment)", {})
        vim.api.nvim_set_keymap("n", "<C-x>", "<Plug>(dial-decrement)", {})
        vim.api.nvim_set_keymap("v", "<C-a>", "<Plug>(dial-increment)", {})
        vim.api.nvim_set_keymap("v", "<C-x>", "<Plug>(dial-decrement)", {})
      end
    }
    use {
      "sindrets/diffview.nvim",
      config = function() require("plugins.diffview") end,
      cmd = {"DiffviewOpen"}
    }
    use {
      "lukas-reineke/indent-blankline.nvim",
      config = function() require("plugins.indent-blankline") end
    }
    use {
      "simrat39/symbols-outline.nvim",
      config = function() vim.g.symbols_outline = {} end,
      cmd = {"SymbolOutline", "SymbolOutlineOpen"}
    }

    use {"hrsh7th/vim-vsnip"}
    use {"hrsh7th/vim-vsnip-integ"}
    use {"rafamadriz/friendly-snippets"}
    use {
      "dsznajder/vscode-es7-javascript-react-snippets",
      run = "yarn install --frozen-lockfile && yarn compile"
    }
    use {
      "sheerun/vim-polyglot",
      setup = function()
        vim.g.polyglot_disabled = {
          "ruby.plugin", "typescript.plugin", "typescriptreact.plugin",
          "lua.plugin", "sensible"
        }
      end
    }
    use {
      "phaazon/hop.nvim",
      as = "hop",
      config = function()
        require"hop".setup {keys = "etovxqpdygfblzhckisuran"}
      end
    }

    use {"tpope/vim-abolish"}
    use {
      "b3nj5m1n/kommentary",
      setup = function() vim.g.kommentary_create_default_mappings = false end,
      config = function() require("plugins.commenting") end
    }
    use {"tpope/vim-dispatch", cmd = {"Dispatch", "Make", "Focus", "Start"}}
    use {"tpope/vim-eunuch"}
    use {"tpope/vim-projectionist"}
    use {"tpope/vim-rails", ft = {"ruby"}}
    use {"tpope/vim-repeat"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar"}
    use {"axelf4/vim-strip-trailing-whitespace"}

  end,
  config = {
    opt_default = false,
    display = {
      open_fn = function()
        return require("packer.util").float({border = "rounded"})
      end,
      prompt_border = "rounded"
    }
  }
})
