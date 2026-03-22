return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = "BufReadPost",
    init = function()
      -- Custom predicate for mise config file detection (used by queries/toml/injections.scm)
      require("vim.treesitter.query").add_predicate("is-mise?", function(_, _, bufnr, _)
        local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
        local filename = vim.fn.fnamemodify(filepath, ":t")
        return string.match(filename, ".*mise.*%.toml$") ~= nil
      end, { force = true, all = false })
    end,
    config = function()
      -- Auto-install tree-sitter CLI if not present
      if vim.fn.executable("tree-sitter") == 0 then
        vim.notify("tree-sitter CLI not found, installing...", vim.log.levels.INFO)

        local install_cmd
        if vim.fn.has("win32") == 1 then
          install_cmd = { "scoop", "install", "tree-sitter" }
        elseif vim.fn.has("mac") == 1 then
          install_cmd = { "brew", "install", "tree-sitter" }
        else
          install_cmd = { "npm", "install", "-g", "tree-sitter-cli" }
        end

        vim.system(install_cmd, { text = true }, function(obj)
          if obj.code == 0 then
            vim.notify("tree-sitter CLI installed successfully!", vim.log.levels.INFO)
          else
            vim.notify(
              "Failed to install tree-sitter CLI. Please install manually:\n"
                .. "  Windows: scoop install tree-sitter\n"
                .. "  macOS: brew install tree-sitter\n"
                .. "  Linux: npm install -g tree-sitter-cli",
              vim.log.levels.WARN
            )
          end
        end)
      end

      require("nvim-treesitter").setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "TSUpdate",
        callback = function()
          require("nvim-treesitter.parsers").papyrus = {
            install_info = {
              path = "~/Code/tree-sitter-papyrus/",
              branch = "dev",
              generate = true,
              generate_from_json = false,
              queries = "queries",
            },
          }
        end,
      })
    end,
  },
  {
    "MeanderingProgrammer/treesitter-modules.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      ensure_installed = {},
      ignore_install = {},
      sync_install = false,
      auto_install = true,
      fold = { enable = true },
      highlight = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<CR>",
          node_incremental = "<CR>",
          node_decremental = "<BS>",
        },
      },
      indent = { enable = true },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "BufReadPost",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
