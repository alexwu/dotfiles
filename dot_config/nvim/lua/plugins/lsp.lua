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

      vim.lsp.enable("ruff")
      vim.lsp.config("basedpyright", {
        settings = {
          pyright = {
            -- Using Ruff's import organizer
            disableOrganizeImports = true,
          },
          python = {
            analysis = {
              -- Ignore all files for analysis to exclusively use Ruff for linting
              ignore = { "*" },
            },
          },
        },
      })
      vim.lsp.enable("basedpyright")

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

      -- LSP keymaps
      local function hover()
        local filetype = vim.filetype.match({ buf = 0 })
        if vim.tbl_contains({ "vim", "help" }, filetype) then
          vim.cmd("h " .. vim.fn.expand("<cword>"))
        elseif vim.tbl_contains({ "man" }, filetype) then
          vim.cmd("Man " .. vim.fn.expand("<cword>"))
        -- elseif vim.fn.expand("%:t") == "Cargo.toml" then
        --   require("crates").show_popup()
        else
          require("pretty_hover").hover()
        end
      end

      set("i", "<C-y>", function()
        if not vim.lsp.inline_completion.get() then
          return "<C-y>"
        end
      end, { expr = true, desc = "Accept the current inline completion" })

      set("n", "gd", function()
        vim.lsp.buf.definition()
      end, { silent = true, desc = "Go to definition" })

      set("n", "grr", function()
        vim.lsp.buf.references()
      end, { desc = "Go to references" })

      set("n", "gri", function()
        vim.lsp.buf.implementation()
      end, { desc = "Go to implementation" })

      set("n", "grt", function()
        vim.lsp.buf.type_definition()
      end, { desc = "Go to type definition" })

      set("n", "grx", function()
        vim.lsp.codelens.run()
      end, { desc = "Run code lens" })
      set("n", "K", hover, { silent = true, desc = "Hover" })
      set({ "n", "x" }, "gra", require("tiny-code-action").code_action, { desc = "Select a code action" })
    end,
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    cond = function()
      return vim.g.vscode == nil
    end,
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
