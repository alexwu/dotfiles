return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    event = "BufReadPre",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      automatic_enable = {
        exclude = { "harper-ls", "harper_ls", "lua_ls", "lua-language-server" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
    config = function()
      vim.diagnostic.config({
        virtual_text = false,
        underline = {
          severity = vim.diagnostic.severity.ERROR,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ✘",
            [vim.diagnostic.severity.WARN] = "  ",
            [vim.diagnostic.severity.HINT] = "  ",
            [vim.diagnostic.severity.INFO] = "  ",
          },
        },
        float = {
          show_header = false,
          source = true,
        },
        update_in_insert = false,
      })

      -- Generic LSP servers
      vim.lsp.enable("taplo")
      vim.lsp.enable("yamlls")
      vim.lsp.enable("zls")
      vim.lsp.enable("markdown_oxide")
      vim.lsp.enable("emmylua_ls")
      vim.lsp.enable("sourcekit")
      vim.lsp.enable("gdscript")

      vim.lsp.config("sqruff", {
        root_markers = { ".sqruff" },
      })
      vim.lsp.enable("sqruff")

      vim.lsp.config("typos_lsp", {
        init_options = {
          diagnosticSeverity = "Warning",
        },
      })
      vim.lsp.enable("typos_lsp")

      -- LSP keymaps
      local set = vim.keymap.set

      set("n", "gd", function()
        vim.lsp.buf.definition()
      end, { silent = true, desc = "Go to definition" })

      set("n", "grr", function()
        vim.lsp.buf.references()
      end, { desc = "Go to references" })

      set("n", "gri", function()
        vim.lsp.buf.implementation()
      end, { desc = "Go to implementation" })

      set("n", "gry", function()
        vim.lsp.buf.type_definition()
      end, { desc = "Go to type definition" })

      set("n", "K", vim.lsp.buf.hover, { silent = true, desc = "Hover" })
    end,
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    cond = function()
      return vim.g.vscode == nil
    end,
    opts = {
      options = { show_source = true, multiple_diag_under_cursor = true },
    },
  },
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    keys = {
      {
        "grn",
        function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Rename symbol",
      },
    },
    opts = { input_buffer_type = "snacks" },
  },
}
