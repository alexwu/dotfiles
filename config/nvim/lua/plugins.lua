local needs_packer = require("utils").needs_packer
local install_packer = require("utils").install_packer
local packer_bootstrap = nil

local install_path = vim.fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if needs_packer(install_path) then
  packer_bootstrap = install_packer(install_path)
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
    use { "lewis6991/impatient.nvim" }
    use {
      "antoinemadec/FixCursorHold.nvim",
      config = function()
        vim.g.curshold_updatime = 250
      end,
    }
    use { "nvim-lua/plenary.nvim" }
    use { "~/Code/neovim/nvim-snazzy" }
    use { "nvim-treesitter/nvim-treesitter" }
    use {
      "numToStr/Comment.nvim",
      config = function()
        require "plugins.commenting"
      end,
      requires = { "JoosepAlviste/nvim-ts-context-commentstring" },
    }

    -- important
    use {
      "knubie/vim-kitty-navigator",
      run = "cp ./*.py ~/.config/kitty/",
      config = function()
        require "plugins.kitty"
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
        "kosayoda/nvim-lightbulb",
        "hrsh7th/cmp-nvim-lsp",
        "weilbith/nvim-code-action-menu",
        "nvim-telescope/telescope.nvim",
        "b0o/schemastore.nvim",
      },
    }

    use {
      "hrsh7th/nvim-cmp",
      requires = {
        "onsails/lspkind-nvim",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-nvim-lsp",
        "ray-x/cmp-treesitter",
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-buffer",
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
        { "nvim-telescope/telescope-ui-select.nvim" },
        { "tami5/sqlite.lua", module = "sqlite" },
        { "AckslD/nvim-neoclip.lua" },
      },
      config = function()
        require "plugins.telescope"
      end,
    }

    use {
      "vim-test/vim-test",
      config = function()
        require "plugins.vim-test"
      end,
      requires = { "akinsho/toggleterm.nvim" },
    }

    -- use {
    --   "windwp/windline.nvim",
    --   config = function()
    --     require "statusline"
    --
    --     require("wlfloatline").toggle()
    --   end,
    -- }
    use {
      "nvim-lualine/lualine.nvim",
      requires = {
        "kyazdani42/nvim-web-devicons",
        "arkav/lualine-lsp-progress",
        { "SmiteshP/nvim-gps", requires = "nvim-treesitter/nvim-treesitter" },
      },
      config = function()
        require "statusline"
      end,
    }

    use { "nvim-treesitter/nvim-treesitter-textobjects" }
    use { "nvim-treesitter/nvim-treesitter-refactor" }
    use { "RRethy/nvim-treesitter-textsubjects" }

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
        vim.g.matchup_matchparen_deferred = 1
        vim.g.matchup_matchparen_offscreen = { method = "popup" }
      end,
    }

    use {
      "rcarriga/nvim-notify",
      requires = { "nvim-telescope/telescope.nvim" },
      config = function()
        require "plugins.notify"
      end,
    }

    -- use {
    --   "folke/which-key.nvim",
    --   config = function()
    --     require("which-key").setup {}
    --   end,
    -- }

    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = { "jose-elias-alvarez/null-ls.nvim" },
    }

    use {
      "simrat39/rust-tools.nvim",
      requires = {
        "nvim-lua/popup.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
      },
    }

    use {
      "rcarriga/nvim-dap-ui",
      requires = { "mfussenegger/nvim-dap" },
      config = function()
        require("dapui").setup()
      end,
      disable = true,
    }

    use {
      "NTBBloodbath/rest.nvim",
      requires = { "nvim-lua/plenary.nvim" },
      config = function()
        require("rest-nvim").setup {
          result_split_horizontal = false,
          skip_ssl_verification = false,
          highlight = {
            enabled = true,
            timeout = 150,
          },
          result = {
            show_url = true,
            show_http_info = true,
            show_headers = true,
          },
          jump_to_request = false,
          env_file = ".env",
          custom_dynamic_variables = {},
        }
        vim.keymap.set("n", "<leader>rq", "<Plug>RestNvim")
        -- vim.cmd [[ command! -nargs=0 Query <Plug>RestNvim ]]
      end,
      disable = true,
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
      "kyazdani42/nvim-tree.lua",
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
      disable = true,
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
        require "plugins.dial"
      end,
    }
    use {
      "sindrets/diffview.nvim",
      config = function()
        require "plugins.diffview"
      end,
    }
    use {
      "lukas-reineke/indent-blankline.nvim",
      config = function()
        require "plugins.indent-blankline"
      end,
      -- after = "windline.nvim",
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
      "tpope/vim-projectionist",
      requires = { "tpope/vim-dispatch" },
      config = function()
        require "plugins.projectionist"
      end,
    }
    use { "tpope/vim-repeat" }
    use { "tpope/vim-surround" }
    -- use { "tpope/vim-rails" }
    use { "chaoren/vim-wordmotion" }
    use { "junegunn/vim-easy-align" }
    use { "AndrewRadev/splitjoin.vim" }

    use {
      "karb94/neoscroll.nvim",
      config = function()
        require "plugins.neoscroll"
      end,
    }

    use {
      "beauwilliams/focus.nvim",
      config = function()
        require "plugins.focus"
      end,
      disable = true,
    }

    if packer_bootstrap then
      require("packer").sync()
    end
  end,
  config = {
    opt_default = false,
    log = "debug",
    max_jobs = 9,
    display = {
      open_fn = function()
        return require("packer.util").float { border = "rounded" }
      end,
    },
  },
}
