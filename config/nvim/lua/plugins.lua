local cmd = vim.cmd
local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath("data") .. "/site/pack/packer/opt/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  execute("!git clone https://github.com/wbthomason/packer.nvim " ..
            install_path)
end

cmd [[packadd packer.nvim]]

return require("packer").startup({
  function()
    use {"wbthomason/packer.nvim", opt = true}

    use {"nvim-treesitter/nvim-treesitter", run = ":TSUpdate"}
    use {"nvim-treesitter/nvim-treesitter-refactor"}
    use {"nvim-treesitter/playground"}
    use {"neovim/nvim-lspconfig"}
    use {"windwp/nvim-autopairs"}
    use {"norcalli/nvim-colorizer.lua"}
    use {"RishabhRD/nvim-lsputils", requires = {"RishabhRD/popfix"}}
    use {"lewis6991/gitsigns.nvim", requires = {"nvim-lua/plenary.nvim"}}
    use {"f-person/git-blame.nvim"}
    use {"kosayoda/nvim-lightbulb"}
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
    use {"onsails/lspkind-nvim"}
    use {"datwaft/bubbly.nvim"}
    use {"antoinemadec/FixCursorHold.nvim"}
    use {"lukas-reineke/indent-blankline.nvim", branch = "lua"}
    use {"glepnir/lspsaga.nvim"}
    use {"phaazon/hop.nvim"}

    use {"chaoren/vim-wordmotion"}
    use {"junegunn/fzf.vim", requires = {{"junegunn/fzf"}}}
    use {"sheerun/vim-polyglot"}
    use {"skywind3000/asyncrun.vim"}
    use {"tpope/vim-abolish"}
    use {"tpope/vim-bundler"}
    use {"tpope/vim-commentary"}
    use {"tpope/vim-dispatch"}
    use {"tpope/vim-eunuch"}
    use {"tpope/vim-fugitive"}
    use {"tpope/vim-projectionist"}
    use {"tpope/vim-rails"}
    use {"tpope/vim-repeat"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar"}
    use {"vim-test/vim-test"}
    use {"voldikss/vim-floaterm"}

    use {"~/Code/nvim-snazzy"}
  end,
  config = {compile_path = fn.stdpath("data") .. "packer/packer_compiled.vim"}
})
