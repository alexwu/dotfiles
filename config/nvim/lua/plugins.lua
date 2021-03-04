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
    use {"nvim-treesitter/playground"}
    use {
      "neovim/nvim-lspconfig",
      config = function() require"colorizer".setup() end
    }
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
    use {"hrsh7th/nvim-compe"}
    use {"onsails/lspkind-nvim"}
    use {"datwaft/bubbly.nvim", config = function() require("statusline") end}
    use {"antoinemadec/FixCursorHold.nvim"}

    use {"lukas-reineke/indent-blankline.nvim", branch = "lua"}
    use {"chaoren/vim-wordmotion"}
    use {"easymotion/vim-easymotion"}
    use {"junegunn/fzf.vim", requires = {{"junegunn/fzf"}}}
    -- use {"machakann/vim-highlightedyank"}
    use {"tpope/vim-abolish"}
    use {"tpope/vim-commentary"}
    use {"tpope/vim-eunuch"}
    use {"tpope/vim-fugitive"}
    use {"tpope/vim-projectionist"}
    use {"tpope/vim-repeat"}
    use {"tpope/vim-surround"}
    use {"tpope/vim-vinegar"}
    use {"vim-test/vim-test"}
    use {"voldikss/vim-floaterm"}

    use {"/Users/jamesbombeelu/Code/nvim-snazzy"}
  end,
  config = {compile_path = fn.stdpath("data") .. "packer/packer_compiled.vim"}
})
