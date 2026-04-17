local utils = require("bombeelu.utils")

return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
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
    lazy = false,
    opts = {
      servers = {
        "basedpyright",
        "biome",
        "denols",
        "emmylua_ls",
        "eslint",
        "gdscript",
        "html",
        "just",
        "markdown_oxide",
        "oxlint",
        "ruby_lsp",
        "ruff",
        "sorbet",
        "sourcekit",
        "sqruff",
        "tailwindcss",
        "taplo",
        "ts_query_ls",
        "ty",
        "typos_lsp",
        "vimdoc_ls",
        "vtsls",
        "yamlls",
        "zk",
        "zls",
      },
    },
    opts_extend = { "servers" },
    config = function(_, opts)
      -- LSP progress → native echo + statusline redraw
      vim.api.nvim_create_autocmd("LspProgress", {
        callback = function(ev)
          local value = ev.data.params.value
          vim.api.nvim_echo({ { value.message or "done" } }, false, {
            id = "lsp." .. ev.data.params.token,
            kind = "progress",
            source = "vim.lsp",
            title = value.title,
            status = value.kind ~= "end" and "running" or "success",
            percent = value.percentage,
          })
          vim.cmd.redrawstatus()
        end,
      })

      vim.diagnostic.config({
        virtual_text = false,
        underline = {
          severity = vim.diagnostic.severity.ERROR,
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ✘",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = " ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
        float = {
          show_header = false,
          source = true,
        },
        update_in_insert = false,
      })

      -- Enable LSP features when supported
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          if not client then
            return
          end

          if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
          end

          if client:supports_method("textDocument/linkedEditingRange") then
            vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
          end
        end,
      })

      -- Per-server overrides live in `after/lsp/<name>.lua` — Neovim merges
      -- those files with nvim-lspconfig's base config automatically.

      -- Defer enable until after startup completes. Running synchronously
      -- inside the config function (or even via vim.schedule) races with
      -- runtime setup and silently fails to register some servers (notably
      -- emmylua_ls).
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          vim.lsp.enable(opts.servers)
        end,
      })

      -- vim.lsp.inline_completion.enable()
      -- vim.lsp.config("copilot", {
      --   settings = {
      --     telemetry = {
      --       telemetryLevel = "off",
      --     },
      --   },
      -- })
      -- vim.lsp.enable("copilot")
      -- vim.api.nvim_create_autocmd("LspAttach", {
      --   callback = function(args)
      --     local bufnr = args.buf
      --     local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      --
      --     if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
      --       vim.lsp.inline_completion.enable(true, { bufnr = bufnr })
      --
      --       vim.keymap.set(
      --         "i",
      --         "<C-F>",
      --         vim.lsp.inline_completion.get,
      --         { desc = "LSP: accept inline completion", buffer = bufnr }
      --       )
      --       vim.keymap.set(
      --         "i",
      --         "<C-G>",
      --         vim.lsp.inline_completion.select,
      --         { desc = "LSP: switch inline completion", buffer = bufnr }
      --       )
      --     end
      --   end,
      -- })
      -- vim.lsp.enable("copilot")
    end,
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    cond = utils.not_vscode,
    opts = {
      options = {
        show_source = { enabled = true },
        show_all_diags_on_cursorline = true,
      },
    },
    config = function(_, opts)
      require("tiny-inline-diagnostic").setup(opts)

      Snacks.toggle
        .new({
          id = "tiny-inline-diagnostic",
          name = "Inline Diagnostics",
          get = function()
            return require("tiny-inline-diagnostic").is_enabled()
          end,
          set = function(state)
            if state then
              require("tiny-inline-diagnostic").enable()
            else
              require("tiny-inline-diagnostic").disable()
            end
          end,
        })
        :map("<leader>up")
    end,
  },
  {
    "rachartier/tiny-code-action.nvim",
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      {
        "folke/snacks.nvim",
        opts = {
          terminal = {},
        },
      },
    },
    event = "LspAttach",
    opts = {
      backend = "vim",
      picker = "snacks",
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
  {
    "yioneko/nvim-vtsls",
    lazy = true,
    init = function()
      local loaded = false
      local function check()
        local result = vim.fs.root(0, { "tsconfig.json" })

        if result then
          require("lazy").load({ plugins = { "nvim-vtsls" } })
          loaded = true
        end
      end
      check()
      vim.api.nvim_create_autocmd("DirChanged", {
        group = require("bu").nvim.augroup("vtsls.custom"),
        callback = function()
          if not loaded then
            check()
          end
        end,
      })
    end,
    keys = {
      {
        "gD",
        function()
          require("vtsls").commands.goto_source_definition(0)
        end,
        desc = "Goto Source Definition",
      },
      {
        "<leader>co",
        function()
          require("vtsls").commands.organize_imports(0)
        end,
        desc = "Organize Imports",
      },
      {
        "gro",
        function()
          require("vtsls").commands.organize_imports(0)
        end,
        desc = "Organize Imports",
      },
      {
        "<leader>cM",
        function()
          require("vtsls").commands.add_missing_imports(0)
        end,
        desc = "Add missing imports",
      },
      {
        "<leader>cu",
        function()
          require("vtsls").commands.remove_unused_imports(0)
        end,
        desc = "Remove unused imports",
      },
      {
        "gru",
        function()
          require("vtsls").commands.remove_unused_imports(0)
        end,
        desc = "Remove unused imports",
      },
      {
        "<leader>cU",
        function()
          require("vtsls").commands.remove_unused(0)
        end,
        desc = "Remove unused",
      },
      {
        "grU",
        function()
          require("vtsls").commands.remove_unused(0)
        end,
        desc = "Remove unused",
      },
    },
  },
}
