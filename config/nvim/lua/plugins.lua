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
    -- Lua
    --[[ use {
      "abecodes/tabout.nvim",
      config = function()
        require("tabout").setup {
          tabkey = "<Tab>",
          act_as_tab = true,
          completion = true,
          tabouts = {
            {open = "'", close = "'"}, {open = "\"", close = "\""},
            {open = "`", close = "`"}, {open = "(", close = ")"},
            {open = "[", close = "]"}, {open = "{", close = "}"}
          },
          ignore_beginning = true,
          exclude = {}
        }
      end,
      wants = {"nvim-treesitter"},
      after = {"nvim-compe"}
    } ]]

    -- NeoVim LSP
    use {
      "neovim/nvim-lspconfig",
      config = function() require("plugins/lsp") end
    }
    use {"williamboman/nvim-lsp-installer"}
    use {"folke/lsp-trouble.nvim", requires = "kyazdani42/nvim-web-devicons"}
    use {"ray-x/lsp_signature.nvim"}

    -- TypeScript LSP Utilities
    use {
      "jose-elias-alvarez/nvim-lsp-ts-utils",
      requires = {"jose-elias-alvarez/null-ls.nvim"},
      ft = {
        "javascript", "javascriptreact", "typescript", "typescriptreact",
        "typescript.tsx"
      }
    }
    use {"mfussenegger/nvim-lint"}

    --[[ use {
      "ms-jpq/coq_nvim",
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
    use {"ms-jpq/coq.artifacts", branch = "artifacts", after = "coq_nvim"} ]]

    -- Rust LSP Utilities
    use {"simrat39/rust-tools.nvim", ft = {"rust"}}

    use {
      "nvim-telescope/telescope.nvim",
      requires = {
        {"nvim-lua/popup.nvim"}, {"nvim-lua/plenary.nvim"},
        {"nvim-telescope/telescope-fzf-native.nvim", run = "make"},
        {"kyazdani42/nvim-web-devicons"}
      }
    }
    use {
      "ibhagwan/fzf-lua",
      requires = {"kyazdani42/nvim-web-devicons", "vijaymarupudi/nvim-fzf"}
    }

    use {"vim-test/vim-test"}
    use {
      "rcarriga/vim-ultest",
      requires = {"vim-test/vim-test"},
      run = ":UpdateRemotePlugins"
    }

    use {
      "kyazdani42/nvim-tree.lua",
      requires = {"kyazdani42/nvim-web-devicons"},
      config = function() require("plugins/tree") end
    }
    use {
      "hrsh7th/nvim-compe",
      requires = {"onsails/lspkind-nvim"},
      config = function() require("plugins/compe") end
    }
    use {"tzachar/compe-tabnine", after = "nvim-compe", event = "InsertEnter"}
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
      config = function() require("colorizer").setup() end,
      cmd = {"ColorizerToggle"}
    }
    use {
      "lewis6991/gitsigns.nvim",
      requires = {"nvim-lua/plenary.nvim"},
      config = function()
        require("gitsigns").setup({current_line_blame = false})
      end
    }
    use {
      "mhartington/formatter.nvim",
      config = function() require("plugins/formatter") end
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
    use {"sindrets/diffview.nvim"}
    use {"lukas-reineke/indent-blankline.nvim"}
    use {
      "simrat39/symbols-outline.nvim",
      config = function() vim.g.symbols_outline = {} end
    }

    use {"hrsh7th/vim-vsnip"}
    use {"hrsh7th/vim-vsnip-integ"}
    use {"rafamadriz/friendly-snippets"}
    use {
      "dsznajder/vscode-es7-javascript-react-snippets",
      run = "yarn install --frozen-lockfile && yarn compile"
    }
    -- use {"chaoren/vim-wordmotion"}
    use {"sheerun/vim-polyglot"}
    use {"tpope/vim-abolish"}
    use {"tpope/vim-bundler"}
    use {
      "b3nj5m1n/kommentary",
      config = function() require("plugins/commenting") end
    }
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
    use {
      "voldikss/vim-floaterm",
      config = function() require("plugins/floaterm") end
    }
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
