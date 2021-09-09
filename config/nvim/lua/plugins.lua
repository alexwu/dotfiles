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
      config = function() require("plugins.lsp") end,
      requires = {
        "williamboman/nvim-lsp-installer", "ray-x/lsp_signature.nvim",
        "kosayoda/nvim-lightbulb"
      }
    }

    use {"nvim-treesitter/nvim-treesitter", run = ":TSUpdate"}
    use {"nvim-treesitter/nvim-treesitter-refactor"}
    use {"nvim-treesitter/nvim-treesitter-textobjects"}
    use {
      "nvim-treesitter/playground",
      opt = true,
      cmd = "TSHighlightCapturesUnderCursor"
    }
    use {
      "windwp/nvim-autopairs",
      config = function()
        require("nvim-autopairs").setup({map_bs = false, check_ts = false})
      end
    }
    use {"windwp/nvim-ts-autotag"}
    use {"JoosepAlviste/nvim-ts-context-commentstring"}
    use {"andymass/vim-matchup"}

    use {
      "SmiteshP/nvim-gps",
      requires = "nvim-treesitter/nvim-treesitter",
      config = function() require("nvim-gps").setup() end
    }

    use {
      "nvim-telescope/telescope.nvim",
      requires = {
        {"nvim-lua/plenary.nvim"},
        {"nvim-telescope/telescope-fzf-native.nvim", run = "make"},
        {"kyazdani42/nvim-web-devicons"},
        {"nvim-telescope/telescope-frecency.nvim", requires = "tami5/sql.nvim"},
        {"nvim-telescope/telescope-hop.nvim"}, {"AckslD/nvim-neoclip.lua"},
        {"nvim-telescope/telescope-github.nvim"}
      },
      config = function() require("plugins.telescope") end
    }

    use {
      "hrsh7th/nvim-cmp",
      requires = {
        "onsails/lspkind-nvim", "hrsh7th/cmp-buffer", "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-path", "hrsh7th/cmp-vsnip", "hrsh7th/cmp-emoji",
        "hrsh7th/cmp-nvim-lsp", "ray-x/cmp-treesitter"
      },
      config = function() require("plugins.cmp") end
    }
    use {
      "tzachar/cmp-tabnine",
      run = "./install.sh",
      requires = "hrsh7th/nvim-cmp"
    }
    use {"lewis6991/impatient.nvim"}

    use {
      "antoinemadec/FixCursorHold.nvim",
      config = function() vim.g.curshold_updatime = 250 end
    }

    use {
      "rcarriga/nvim-notify",
      config = function() vim.notify = require("notify") end
    }

    use {
      "folke/lsp-trouble.nvim",
      requires = "kyazdani42/nvim-web-devicons",
      config = function() require("plugins.trouble") end,
      cmd = {"Trouble", "TroubleToggle"}
    }

    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = {"jose-elias-alvarez/null-ls.nvim"}
    }

    use {"simrat39/rust-tools.nvim", ft = {"rust"}}
    use {"gennaro-tedesco/nvim-jqx", ft = "json"}

    use {"pwntester/octo.nvim", config = function() require"octo".setup() end}
    use {"kevinhwang91/nvim-bqf"}

    use {
      "beauwilliams/focus.nvim",
      config = function()
        local focus = require("focus")
        focus.enable = true
        focus.treewidth = 35
      end,
      cmd = {"FocusEnable", "FocusToggle"}
    }

    use {
      "ibhagwan/fzf-lua",
      requires = {"kyazdani42/nvim-web-devicons", "vijaymarupudi/nvim-fzf"},
      config = function() require("plugins.fzf") end
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
      setup = function() require("plugins.tree") end
    }

    use {
      "akinsho/toggleterm.nvim",
      config = function() require("plugins.terminal") end
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
      config = function() require("plugins.diffview") end
    }
    use {
      "lukas-reineke/indent-blankline.nvim",
      config = function() require("plugins.indent-blankline") end
    }

    use {"hrsh7th/vim-vsnip"}
    use {"hrsh7th/vim-vsnip-integ"}
    use {"rafamadriz/friendly-snippets"}
    use {
      "dsznajder/vscode-es7-javascript-react-snippets",
      run = "yarn install --frozen-lockfile && yarn compile"
    }

    use {
      "knubie/vim-kitty-navigator",
      run = "cp ./*.py ~/.config/kitty/",
      config = function() require("plugins.kitty") end
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
      "b3nj5m1n/kommentary",
      setup = function() vim.g.kommentary_create_default_mappings = false end,
      config = function() require("plugins.commenting") end
    }

    use {
      "tpope/vim-projectionist",
      cond = "true",
      requires = {"tpope/vim-dispatch"}
    }
    use {"tpope/vim-eunuch"}
    use {"tpope/vim-rails", ft = {"ruby"}}
    use {"tpope/vim-repeat"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar", disable = true}
    use {"axelf4/vim-strip-trailing-whitespace"}
    use {"chaoren/vim-wordmotion"}

  end,
  config = {
    opt_default = false,
    display = {
      open_fn = function()
        return require("packer.util").float({border = "rounded"})
      end,
      prompt_border = "rounded"
    },
    log = "debug",
    max_jobs = 9
  }
})
