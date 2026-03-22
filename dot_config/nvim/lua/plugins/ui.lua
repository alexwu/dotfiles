return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
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
      { "g?", function() require("which-key").show({ global = true }) end, desc = "Keymaps (which-key)" },
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps (which-key)" },
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
    cond = function() return vim.g.vscode == nil end,
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
          if vim.wo.diff then return "]c" end
          vim.schedule(function() gs.next_hunk({ navigation_message = false, preview = false }) end)
          return "<Ignore>"
        end, { expr = true, desc = "Next Git hunk" })

        map("n", "[c", function()
          if vim.wo.diff then return "[c" end
          vim.schedule(function() gs.prev_hunk({ navigation_message = false, preview = false }) end)
          return "<Ignore>"
        end, { expr = true, desc = "Previous Git hunk" })

        map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
        map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
        map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
        map("n", "<leader>hb", gs.stage_buffer, { desc = "Stage buffer" })
        map("n", "<leader>hR", gs.reset_buffer, { desc = "Reset buffer" })
        map("n", "gM", function() gs.blame_line({ full = true, ignore_whitespace = true }) end, { desc = "Git blame" })
        map("n", "M", gs.preview_hunk, { desc = "Preview hunk" })
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Inner Git hunk" })
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    cond = function() return vim.g.vscode == nil end,
  },

  {
    "vim-test/vim-test",
    cmd = { "TestNearest", "TestFile", "TestSuite", "TestLast", "TestVisit" },
  },

  {
    "stevearc/overseer.nvim",
    cmd = { "OverseerRun", "OverseerToggle" },
    cond = function() return vim.g.vscode == nil end,
    opts = {},
  },

  {
    "chrisgrieser/nvim-tinygit",
    cond = function() return vim.g.vscode == nil end,
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
