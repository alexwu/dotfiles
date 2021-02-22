local cmd = vim.cmd
local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  execute('!git clone https://github.com/wbthomason/packer.nvim '..install_path)
end

cmd [[packadd packer.nvim]]

return require('packer').startup({ function()
  use { 'wbthomason/packer.nvim', opt = true }
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
  use {'junegunn/fzf'}
  use {'junegunn/fzf.vim'}
  use {
    'glepnir/lspsaga.nvim',
    requires = {'neovim/nvim-lspconfig'}
  }
  use {
    'lewis6991/gitsigns.nvim',
    requires = {
      'nvim-lua/plenary.nvim'
    }
  }
  use { 'Yggdroot/indentLine' }
  use { 'chaoren/vim-wordmotion' }
  use { 'connorholyday/vim-snazzy' }
  use { 'f-person/git-blame.nvim' }
  use { 'hrsh7th/nvim-compe' }
  use { 'tpope/vim-abolish' }
  use { 'tpope/vim-commentary' }
  use { 'tpope/vim-eunuch' }
  use { 'tpope/vim-projectionist' }
  use { 'tpope/vim-surround' }
  use { 'tpope/vim-vinegar' }
  use { 'voldikss/vim-floaterm' }
end,
  config = {
    compile_path = fn.stdpath('data')..'packer/packer_compiled.vim',
  } 
})
