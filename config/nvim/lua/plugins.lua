local needs_packer = require("utils").needs_packer
local install_packer = require("utils").install_packer

local install_path = vim.fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if needs_packer(install_path) then
  install_packer(install_path)
end

vim.cmd [[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]]

return require("packer").startup {
  function()
    -- Minimal setup
    use { "wbthomason/packer.nvim" }
    use { "alexwu/nvim-snazzy" }
    use { "nvim-treesitter/nvim-treesitter" }
    use {
      "b3nj5m1n/kommentary",
      setup = function()
        vim.g.kommentary_create_default_mappings = false
      end,
      config = function()
        require "plugins.commenting"
      end,
    }

    -- important
    use {
      "knubie/vim-kitty-navigator",
      run = "cp ./*.py ~/.config/kitty/",
      config = function()
        require "plugins.kitty"
      end,
    }
    use { "lewis6991/impatient.nvim" }
    use {
      "antoinemadec/FixCursorHold.nvim",
      config = function()
        vim.g.curshold_updatime = 250
      end,
    }
    use {
      "mhartington/formatter.nvim",
      config = function()
        require "plugins.formatter"
      end,
    }
    use {
      "L3MON4D3/LuaSnip",
      requires = { "rafamadriz/friendly-snippets" },
      config = function()
        require "plugins.snippets"
      end,
    }
    use {
      "neovim/nvim-lspconfig",
      config = function()
        require "plugins.lsp"
      end,
      requires = {
        "williamboman/nvim-lsp-installer",
        "ray-x/lsp_signature.nvim",
        "kosayoda/nvim-lightbulb",
        "hrsh7th/cmp-nvim-lsp",
      },
    }
    use {
      "hrsh7th/nvim-cmp",
      requires = {
        "onsails/lspkind-nvim",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-nvim-lsp",
        "ray-x/cmp-treesitter",
        "saadparwaiz1/cmp_luasnip",
      },
      config = function()
        require "plugins.cmp"
      end,
    }
    use {
      "tzachar/cmp-tabnine",
      run = "./install.sh",
      requires = "hrsh7th/nvim-cmp",
    }
    use {
      "nvim-telescope/telescope.nvim",
      requires = {
        { "nvim-lua/plenary.nvim" },
        { "nvim-telescope/telescope-fzf-native.nvim", run = "make" },
        { "kyazdani42/nvim-web-devicons" },
        { "nvim-telescope/telescope-hop.nvim" },
      },
      config = function()
        require "plugins.telescope"
      end,
    }
    use {
      "voldikss/vim-floaterm",
      config = function()
        require "plugins.floaterm"
      end,
    }

    use {
      "vim-test/vim-test",
      config = function()
        require "plugins.vim-test"
      end,
    }

    use {
      "AckslD/nvim-neoclip.lua",
      config = function()
        require("neoclip").setup()
        require("telescope").load_extension "neoclip"
      end,
      requires = { "nvim-telescope/telescope.nvim" },
    }

    use {
      "hoob3rt/lualine.nvim",
      requires = {
        "kyazdani42/nvim-web-devicons",
      },
      config = function()
        require "statusline"
      end,
    }

    use { "nvim-treesitter/nvim-treesitter-textobjects" }
    use {
      "nvim-treesitter/playground",
      cmd = { "TSHighlightCapturesUnderCursor", "TSPlaygroundToggle" },
    }

    use {
      "windwp/nvim-autopairs",
      config = function()
        require "plugins.autopairs"
      end,
      requires = { "hrsh7th/nvim-cmp" },
    }
    use { "windwp/nvim-ts-autotag" }
    use { "JoosepAlviste/nvim-ts-context-commentstring" }
    use {
      "andymass/vim-matchup",
      setup = function()
        vim.g.matchup_matchparen_offscreen = { method = "popup" }
      end,
    }

    use {
      "rcarriga/nvim-notify",
      config = function()
        vim.notify = require "notify"
      end,
    }

    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = { "jose-elias-alvarez/null-ls.nvim" },
    }

    use { "gennaro-tedesco/nvim-jqx", ft = { "json" } }

    use { "kevinhwang91/nvim-bqf" }

    use {
      "phaazon/hop.nvim",
      as = "hop",
      config = function()
        require "plugins.hop"
      end,
    }

    use {
      "ibhagwan/fzf-lua",
      requires = { "kyazdani42/nvim-web-devicons", "vijaymarupudi/nvim-fzf" },
      config = function()
        require "plugins.fzf"
      end,
      disable = true,
    }

    use {
      "~/Code/nvim-tree.lua",
      requires = { "kyazdani42/nvim-web-devicons" },
      config = function()
        require "plugins.tree"
      end,
    }

    use {
      "akinsho/toggleterm.nvim",
      config = function()
        require "plugins.terminal"
      end,
    }

    use {
      "folke/todo-comments.nvim",
      config = function()
        require "plugins.todo-comments"
      end,
    }

    use {
      "norcalli/nvim-colorizer.lua",
      config = function()
        require("colorizer").setup()
      end,
      cmd = { "ColorizerToggle" },
    }

    use {
      "lewis6991/gitsigns.nvim",
      requires = { "nvim-lua/plenary.nvim" },
      config = function()
        require "plugins.gitsigns"
      end,
    }

    use {
      "monaqa/dial.nvim",
      config = function()
        vim.api.nvim_set_keymap("n", "<C-a>", "<Plug>(dial-increment)", {})
        vim.api.nvim_set_keymap("n", "<C-x>", "<Plug>(dial-decrement)", {})
        vim.api.nvim_set_keymap("v", "<C-a>", "<Plug>(dial-increment)", {})
        vim.api.nvim_set_keymap("v", "<C-x>", "<Plug>(dial-decrement)", {})
      end,
    }
    use {
      "sindrets/diffview.nvim",
      config = function()
        require "plugins.diffview"
      end,
      cmd = {
        "DiffviewOpen",
        "DiffviewClose",
        "DiffviewFileHistory",
        "DiffviewRefresh",
        "DiffviewFocusFiles",
        "DiffviewToggleFiles",
      },
    }
    use {
      "lukas-reineke/indent-blankline.nvim",
      config = function()
        require "plugins.indent-blankline"
      end,
    }

    use {
      "dsznajder/vscode-es7-javascript-react-snippets",
      run = "yarn install --frozen-lockfile && yarn compile",
    }

    use {
      "lewis6991/spaceless.nvim",
      config = function()
        require("spaceless").setup()
      end,
    }

    use {
      "sheerun/vim-polyglot",
      setup = function()
        vim.g.polyglot_disabled = {
          "ruby.plugin",
          "typescript.plugin",
          "typescriptreact.plugin",
          "lua.plugin",
          "sensible",
        }
      end,
    }

    use { "tpope/vim-projectionist", requires = { "tpope/vim-dispatch" } }
    use { "tpope/vim-rails", ft = { "ruby" } }
    use { "tpope/vim-repeat" }
    use { "tpope/vim-surround" }
    use { "chaoren/vim-wordmotion" }
  end,
  config = {
    opt_default = false,
    log = "debug",
    max_jobs = 9,
  },
}
