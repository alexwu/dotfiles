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
    use {"nvim-treesitter/playground"}
    use {"windwp/nvim-ts-autotag"}
    use {"JoosepAlviste/nvim-ts-context-commentstring"}
    use {"jose-elias-alvarez/nvim-lsp-ts-utils"}

    -- NeoVim specific
    use {"neovim/nvim-lspconfig"}
    use {"windwp/nvim-autopairs"}
    use {"andymass/vim-matchup"}
    use {"norcalli/nvim-colorizer.lua"}
    use {"RishabhRD/nvim-lsputils", requires = {"RishabhRD/popfix"}}
    use {"lewis6991/gitsigns.nvim", requires = {"nvim-lua/plenary.nvim"}}
    use {"f-person/git-blame.nvim"}
    use {"mhartington/formatter.nvim"}
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
      "kyazdani42/nvim-tree.lua",
      requires = {{"kyazdani42/nvim-web-devicons"}}
    }
    use {"hrsh7th/nvim-compe"}
    use {"tzachar/compe-tabnine"}
    use {"gennaro-tedesco/nvim-jqx"}

    use {"onsails/lspkind-nvim"}
    use {"datwaft/bubbly.nvim"}
    use {"lukas-reineke/indent-blankline.nvim", branch = "lua"}
    use {"glepnir/lspsaga.nvim"}
    use {"phaazon/hop.nvim"}
    use {"monaqa/dial.nvim"}
    use "kabouzeid/nvim-lspinstall"
    use "mfussenegger/nvim-dap"
    use "theHamsta/nvim-dap-virtual-text"
    use {"folke/lsp-trouble.nvim", requires = "kyazdani42/nvim-web-devicons"}
    use "folke/lsp-colors.nvim"

    use "rafamadriz/friendly-snippets"
    use {"hrsh7th/vim-vsnip"}
    use {"hrsh7th/vim-vsnip-integ"}
    use {"chaoren/vim-wordmotion"}
    use {"junegunn/fzf.vim", requires = {{"junegunn/fzf"}}}
    use {"sheerun/vim-polyglot"}
    use {"tpope/vim-abolish"}
    use {"tpope/vim-bundler"}
    use {"tpope/vim-commentary"}
    use {"tpope/vim-dispatch"}
    use {"tpope/vim-eunuch"}
    use {"tpope/vim-fugitive"}
    use {"tpope/vim-projectionist"}
    use {"tpope/vim-rails"}
    use {"tpope/vim-repeat"}
    use {"tpope/vim-sensible"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar"}
    use {"vim-test/vim-test"}
    use {"rcarriga/vim-ultest", run = ":UpdateRemotePlugins"}
    use {"voldikss/vim-floaterm"}
    use {"axelf4/vim-strip-trailing-whitespace"}

    use {"~/Code/nvim-snazzy"}
  end,
  config = {compile_path = fn.stdpath("data") .. "packer/packer_compiled.vim"}
})
