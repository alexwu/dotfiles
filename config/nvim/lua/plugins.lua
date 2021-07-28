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

    -- Treesitter
    use {"nvim-treesitter/nvim-treesitter", run = ":TSUpdate"}
    use {"nvim-treesitter/nvim-treesitter-refactor"}
    use {"nvim-treesitter/nvim-treesitter-textobjects"}
    use {"RRethy/nvim-treesitter-textsubjects"}
    use {
      "nvim-treesitter/playground",
      opt = true,
      cmd = "TSHighlightCapturesUnderCursor"
    }
    use {"windwp/nvim-autopairs"}
    use {"windwp/nvim-ts-autotag"}
    use {"JoosepAlviste/nvim-ts-context-commentstring"}
    use {"lewis6991/spellsitter.nvim"}
    use {"andymass/vim-matchup"}

    -- NeoVim LSP
    use {"neovim/nvim-lspconfig"}
    use {"williamboman/nvim-lsp-installer"}
    use {"folke/lsp-trouble.nvim", requires = "kyazdani42/nvim-web-devicons"}
    use {"ray-x/lsp_signature.nvim"}

    -- TypeScript LSP Utilities
    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = {"jose-elias-alvarez/null-ls.nvim"}
    }
    -- Rust LSP Utilities
    use {"simrat39/rust-tools.nvim", ft = {"rust"}}

    use {
      "nvim-telescope/telescope.nvim",
      requires = {
        {"nvim-lua/popup.nvim"}, {"nvim-lua/plenary.nvim"},
        {"nvim-telescope/telescope-fzf-writer.nvim"},
        {"nvim-telescope/telescope-fzy-native.nvim"},
        {"kyazdani42/nvim-web-devicons"}
      }
    }
    use {
      "ibhagwan/fzf-lua",
      requires = {"kyazdani42/nvim-web-devicons", "vijaymarupudi/nvim-fzf"}
    }

    use {"vim-test/vim-test"}

    use {
      "kyazdani42/nvim-tree.lua",
      requires = {{"kyazdani42/nvim-web-devicons"}}
    }
    use {
      "hrsh7th/nvim-compe",
      requires = {"onsails/lspkind-nvim"},
      config = function() require("plugins/compe") end
    }
    use {"tzachar/compe-tabnine"}
    use {"folke/todo-comments.nvim"}
    use {
      "folke/which-key.nvim",
      config = function() require("which-key").setup() end
    }
    use {
      "hoob3rt/lualine.nvim",
      requires = {"kyazdani42/nvim-web-devicons"},
      config = function() require("statusline") end
    }
    use {
      "norcalli/nvim-colorizer.lua",
      config = function() require("colorizer").setup() end
    }
    use {
      "lewis6991/gitsigns.nvim",
      requires = {"nvim-lua/plenary.nvim"},
      config = function()
        require("gitsigns").setup({
          current_line_blame = true,
          current_line_blame_delay = 0
        })
      end
    }
    use {
      "mhartington/formatter.nvim",
      config = function() require("plugins/formatter") end
    }
    use {
      "phaazon/hop.nvim",
      config = function()
        require("hop").setup {keys = "etovxqpdygfblzhckisuran"}
      end
    }
    use {"ggandor/lightspeed.nvim"}
    use {"monaqa/dial.nvim"}
    use {"sindrets/diffview.nvim"}
    use "lukas-reineke/indent-blankline.nvim"

    use {"hrsh7th/vim-vsnip"}
    use {"hrsh7th/vim-vsnip-integ"}
    use {"rafamadriz/friendly-snippets"}
    use {
      "dsznajder/vscode-es7-javascript-react-snippets",
      run = "yarn install --frozen-lockfile && yarn compile"
    }

    use {"chaoren/vim-wordmotion"}
    use {"sheerun/vim-polyglot"}
    use {"tpope/vim-abolish"}
    use {"tpope/vim-bundler"}
    use {"b3nj5m1n/kommentary"}
    use {
      "tpope/vim-dispatch",
      opt = true,
      cmd = {"Dispatch", "Make", "Focus", "Start"}
    }
    use {"tpope/vim-eunuch"}
    use {"tpope/vim-fugitive"}
    use {"tpope/vim-projectionist"}
    use {"tpope/vim-rails", ft = {"ruby"}}
    use {"tpope/vim-repeat"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar"}
    use {"voldikss/vim-floaterm"}
    use {"axelf4/vim-strip-trailing-whitespace"}

    use {"~/Code/nvim-snazzy"}
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
