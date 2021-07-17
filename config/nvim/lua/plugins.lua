local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  execute("!git clone https://github.com/wbthomason/packer.nvim " ..
            install_path)
  execute "packadd packer.nvim"
end

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
    use {
      "folke/twilight.nvim",
      config = function() require("twilight").setup {} end
    }

    -- NeoVim LSP
    use {"neovim/nvim-lspconfig"}
    use {"kabouzeid/nvim-lspinstall"}
    use {"RishabhRD/nvim-lsputils", requires = {"RishabhRD/popfix"}}
    use {"glepnir/lspsaga.nvim"}
    use {"folke/lsp-trouble.nvim", requires = "kyazdani42/nvim-web-devicons"}
    use {"ray-x/lsp_signature.nvim"}

    -- TypeScript LSP Utilities
    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = {"jose-elias-alvarez/null-ls.nvim"}
    }
    -- Rust LSP Utilities
    use {"simrat39/rust-tools.nvim"}

    -- Nightly Required!
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
    use {"hrsh7th/nvim-compe", requires = {"onsails/lspkind-nvim"}}
    use {"tzachar/compe-tabnine"}
    use {"folke/todo-comments.nvim"}
    use {"folke/which-key.nvim"}
    use {"hoob3rt/lualine.nvim", requires = {"kyazdani42/nvim-web-devicons"}}
    use {"norcalli/nvim-colorizer.lua"}
    use {"lewis6991/gitsigns.nvim", requires = {"nvim-lua/plenary.nvim"}}
    use {"mhartington/formatter.nvim"}
    use {"phaazon/hop.nvim"}
    use {"ggandor/lightspeed.nvim"}
    use {"monaqa/dial.nvim"}
    -- use {"pwntester/octo.nvim", config = function() require"octo".setup() end}
    use {"sindrets/diffview.nvim"}

    -- use {"lukas-reineke/indent-blankline.nvim", branch = "lua"}

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
    use {"tpope/vim-commentary"}
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
    use {"tpope/vim-sensible"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar"}
    use {"voldikss/vim-floaterm"}
    use {"axelf4/vim-strip-trailing-whitespace"}
    use {"Yggdroot/indentLine"}

    use {"~/Code/nvim-snazzy"}
    -- use "folke/tokyonight.nvim"

  end,
  config = {
    opt_default = false,
    display = {open_fn = require("packer.util").float}
  }
})
