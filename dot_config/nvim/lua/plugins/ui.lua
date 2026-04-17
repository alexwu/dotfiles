local utils = require("bombeelu.utils")

return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      -- preset = "helix",
      spec = {
        {
          mode = { "n", "v" },
          { "[", group = "prev" },
          { "]", group = "next" },
        },
        {
          mode = { "n" },
          { "<Space>", group = "leader" },
          { "<leader>f", group = "picker" },
        },
      },
      delay = function(ctx)
        return ctx.plugin and 0 or 200
      end,
      triggers = {
        { "<auto>", mode = "nixsotc" },
        { "<leader>", mode = { "n", "v" } },
        { "<space>", mode = { "n" } },
      },
      icons = {
        rules = false,
      },
      layout = {
        height = { min = 4, max = 25 },
        width = { min = 20, max = 50 },
        spacing = 3,
        align = "center",
      },
    },
    keys = {
      {
        "g?",
        function()
          require("which-key").show({ global = true })
        end,
        desc = "Keymaps (which-key)",
      },
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer keymaps (which-key)",
      },
    },
  },

  {
    "mrjones2014/smart-splits.nvim",
    event = "VeryLazy",
    config = function()
      require("smart-splits").setup({})
      _G.set("n", "<C-h>", require("smart-splits").move_cursor_left)
      _G.set("n", "<C-j>", require("smart-splits").move_cursor_down)
      _G.set("n", "<C-k>", require("smart-splits").move_cursor_up)
      _G.set("n", "<C-l>", require("smart-splits").move_cursor_right)
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPre",
    cond = utils.not_vscode,
    opts = {
      sign_priority = 6,
      attach_to_untracked = true,
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = false,
        virt_text_pos = "eol",
        delay = 500,
      },
      preview_config = { border = "rounded" },
      current_line_blame_formatter = " <author>, <author_time:%R> • <summary> ",
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        map("n", "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function()
            gs.next_hunk({ navigation_message = false, preview = false })
          end)
          return "<Ignore>"
        end, { expr = true, desc = "Next Git hunk" })

        map("n", "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function()
            gs.prev_hunk({ navigation_message = false, preview = false })
          end)
          return "<Ignore>"
        end, { expr = true, desc = "Previous Git hunk" })

        map("n", "gssh", gs.stage_hunk, { desc = "Stage hunk" })
        map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
        map({ "n", "v" }, "gsrh", gs.reset_hunk, { desc = "Reset hunk" })
        map({ "n", "v" }, "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
        map("n", "gsuh", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
        map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
        map("n", "gssb", gs.stage_buffer, { desc = "Stage buffer" })
        map("n", "<leader>hb", gs.stage_buffer, { desc = "Stage buffer" })
        map("n", "gsrb", gs.reset_buffer, { desc = "Reset buffer" })
        map("n", "<leader>hR", gs.reset_buffer, { desc = "Reset buffer" })
        map("n", "gM", function()
          gs.blame_line({ full = true, ignore_whitespace = true })
        end, { desc = "Git blame" })
        map("n", "gsdh", function()
          gs.diffthis()
        end, { desc = "Git diff" })
        map("n", "ghD", function()
          gs.diffthis("~")
        end, { desc = "Git diff ~" })
        map("n", "M", gs.preview_hunk, { desc = "Preview hunk" })
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Inner Git hunk" })
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    cond = utils.not_vscode,
  },
  {
    "esmuellert/codediff.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    lazy = false,
    cond = utils.not_vscode,
    opts = {
      explorer = {
        view_mode = "tree",
      },
    },
    keys = {
      {
        "<leader>gD",
        function()
          local git_base = require("bombeelu.git")
          local base_ref, merge_base = git_base.find_base_branch()

          -- CodeDiff takes two revisions: base vs HEAD
          vim.cmd("CodeDiff " .. merge_base .. " HEAD")
        end,
        desc = "CodeDiff (vs base branch)",
      },
    },
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion", "Avante" },
    cond = utils.not_vscode,
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    opts = {
      anti_conceal = { enabled = false },
    },
  },

  {
    "vim-test/vim-test",
    cond = utils.not_vscode,
    cmd = { "TestNearest", "TestFile", "TestSuite", "TestLast", "TestVisit" },
    keys = {
      { "<F7>", vim.cmd.TestNearest, desc = "Run nearest test (vim-test)" },
      { "<F9>", vim.cmd.TestFile, desc = "Run all tests in file (vim-test)" },
    },
    config = function()
      _G.snacks_test_strategy = function(cmd)
        Snacks.terminal.open(cmd, {
          interactive = false,
          auto_close = false,
          win = {
            position = "float",
            border = "rounded",
            width = 0.9,
            height = 0.9,
            keys = {
              q = "hide",
            },
          },
        })
      end

      vim.cmd([[
        function! SnacksTestStrategy(cmd)
          let g:test_cmd = a:cmd
          lua snacks_test_strategy(vim.g.test_cmd)
        endfunction

        let g:test#custom_strategies = {'snacks': function('SnacksTestStrategy')}
      ]])

      vim.g["test#strategy"] = "snacks"
      vim.g["test#ruby#rspec#executable"] = "bundle exec rspec"
      vim.g["test#ruby#rspec#options"] = {
        file = "--format documentation --force-color",
        suite = "--format documentation --force-color",
        nearest = "--format documentation --force-color",
      }
      vim.g["test#javascript#jest#options"] = "--color=always"
      vim.g["test#typescript#jest#options"] = "--color=always"
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    cond = utils.not_vscode,
    dependencies = { "nvim-mini/mini.icons" },
    config = function()
      local colors = {
        background = "#282a36",
        foreground = "#eff0eb",
        black = "#282a36",
        red = "#ff5c57",
        green = "#5af78e",
        yellow = "#f3f99d",
        blue = "#57c7ff",
        purple = "#ff6ac1",
        cyan = "#9aedfe",
        white = "#f1f1f0",
        lightgray = "#b1b1b1",
        darkgray = "#3a3d4d",
      }

      local snazzy_theme = {
        normal = {
          a = { bg = colors.blue, fg = colors.black, gui = "bold" },
          b = { bg = colors.lightgray, fg = colors.white },
          c = { bg = colors.darkgray, fg = colors.lightgray },
        },
        insert = {
          a = { bg = colors.green, fg = colors.black, gui = "bold" },
          b = { bg = colors.lightgray, fg = colors.white },
          c = { bg = colors.darkgray, fg = colors.lightgray },
        },
        visual = {
          a = { bg = colors.purple, fg = colors.black, gui = "bold" },
          b = { bg = colors.lightgray, fg = colors.white },
          c = { bg = colors.darkgray, fg = colors.lightgray },
        },
        replace = {
          a = { bg = colors.red, fg = colors.black, gui = "bold" },
          b = { bg = colors.lightgray, fg = colors.white },
          c = { bg = colors.darkgray, fg = colors.lightgray },
        },
        command = {
          a = { bg = colors.yellow, fg = colors.black, gui = "bold" },
          b = { bg = colors.lightgray, fg = colors.white },
          c = { bg = colors.darkgray, fg = colors.lightgray },
        },
        inactive = {
          a = { bg = colors.darkgray, fg = colors.lightgray, gui = "bold" },
          b = { bg = colors.lightgray, fg = colors.lightgray },
          c = { bg = colors.darkgray, fg = colors.darkgray },
        },
      }

      require("lualine").setup({
        options = {
          theme = snazzy_theme,
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "starter", "snacks_dashboard" },
          },
          component_separators = "|",
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        extensions = { "quickfix", "lazy", "oil", "overseer", "man", "mason" },
        sections = {
          lualine_a = {
            { "mode", separator = {}, right_padding = 2 },
          },
          lualine_b = {
            { "branch", color = { fg = "#3a3d4d", bg = "#f1f1f0" }, separator = { right = "" } },
          },
          lualine_c = {
            {
              "filetype",
              icon_only = true,
              separator = "",
              padding = { left = 1, right = 0 },
            },
            {
              "filename",
              color = { fg = colors.white },
              symbols = {
                modified = "[+]",
                readonly = "[-]",
                unnamed = "",
                newfile = "[New]",
              },
            },
            {
              "diagnostics",
              sources = { "nvim_diagnostic" },
              sections = { "error", "warn", "info", "hint" },
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
              colored = true,
              update_in_insert = false,
              always_visible = false,
            },
          },
          lualine_x = {
            Snacks.profiler.status(),
            {
              function()
                return require("noice").api.status.mode.get()
              end,
              cond = function()
                return package.loaded["noice"] and require("noice").api.status.mode.has()
              end,
              color = { fg = "#ff9e64" },
            },
            {
              require("lazy.status").updates,
              cond = require("lazy.status").has_updates,
              color = { fg = "#ff9e64" },
            },
            {
              "diff",
              symbols = {
                added = " ",
                modified = " ",
                removed = " ",
              },
              source = function()
                local gitsigns = vim.b.gitsigns_status_dict
                if gitsigns then
                  return {
                    added = gitsigns.added,
                    modified = gitsigns.changed,
                    removed = gitsigns.removed,
                  }
                end
              end,
            },
          },
          lualine_y = {},
          lualine_z = {},
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {},
        },
      })
    end,
  },

  -- Pretty hover for LSP
  {
    "Fildo7525/pretty_hover",
    event = "LspAttach",
    opts = {},
  },

  -- Noice: cmdline UI + message routing
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    cond = utils.not_vscode,
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      cmdline = {
        enabled = true,
        view = "cmdline_popup",
      },
      messages = {
        enabled = true,
        view = "notify",
        view_error = "notify",
        view_warn = "notify",
      },
      popupmenu = {
        enabled = true,
        backend = "nui",
      },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
        },
        hover = {
          enabled = false, -- pretty_hover handles this
        },
        signature = {
          enabled = false, -- blink.cmp handles this
        },
        progress = {
          enabled = true,
        },
      },
      presets = {
        bottom_search = false,
        command_palette = true,
        long_message_to_split = true,
        lsp_doc_border = true,
        inc_rename = false, -- snacks input handles this
      },
      routes = {
        {
          filter = { event = "msg_show", kind = "", find = "written" },
          opts = { skip = true },
        },
        {
          filter = { event = "msg_show", kind = "search_count" },
          opts = { skip = true },
        },
      },
    },
    keys = {
      {
        "<leader>nd",
        function()
          require("noice").cmd("dismiss")
        end,
        desc = "Dismiss notifications",
      },
      {
        "<leader>nh",
        function()
          require("noice").cmd("history")
        end,
        desc = "Notification history",
      },
      {
        "<leader>nl",
        function()
          require("noice").cmd("last")
        end,
        desc = "Last notification",
      },
    },
  },

  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle" },
    cond = utils.not_vscode,
    opts = {},
  },

  {
    "chrisgrieser/nvim-tinygit",
    cond = utils.not_vscode,
    config = function()
      require("tinygit").setup({
        commit = {
          mediumLen = 50,
          maxLen = 100,
          preview = {
            loglines = 3,
          },
          wrap = "none",
          subject = {
            enforceType = false,
            types = {
              "fix",
              "feat",
              "chore",
              "docs",
              "refactor",
              "build",
              "test",
              "perf",
              "style",
              "revert",
              "ci",
              "break",
              "improv",
              "custom",
            },
          },
          spellcheck = true,
          openReferencedIssue = false,
        },
      })

      vim.api.nvim_create_user_command("Commit", function()
        require("tinygit").smartCommit({ pushIfClean = false })
      end, {
        desc = "Commit staged changes or all diffs",
      })
    end,
  },
}
