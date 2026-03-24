return {
  {
    "folke/snacks.nvim",
    lazy = false,
    cond = function()
      return vim.g.vscode == nil
    end,
    ---@type fun():snacks.Config
    opts = function()
      local in_git = Snacks.git.get_root() ~= nil
      return {
        input = {},
        gitbrowse = {},
        notifier = {},
        statuscolumn = {},
        picker = {
          enabled = true,
          win = {
            input = {
              keys = {
                ["<Esc>"] = { "close", mode = { "n", "i" } },
                ["<c-u>"] = { "clear_input", mode = { "i" } },
              },
            },
          },
          actions = {
            clear_input = function(picker)
              picker.input:set("")
            end,
          },
        },
        dashboard = {
          preset = {
            pick = nil,
            keys = {
              { icon = " ", key = "f", desc = "Find File", action = ":lua require('fff').find_files()" },
              { icon = " ", key = "/", desc = "Grep", action = ":lua require('fff').live_grep()" },
              { icon = " ", key = "d", desc = "Diff HEAD", action = ":DiffviewOpen", enabled = in_git },
              { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy },
              { icon = " ", key = "q", desc = "Quit", action = ":qa" },
            },
          },
          sections = {
            { section = "keys", gap = 1, padding = 1 },
            { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1, enabled = not in_git },
            function()
              return {
                {
                  pane = 1,
                  section = "terminal",
                  enabled = in_git,
                  padding = 1,
                  ttl = 5 * 60,
                  indent = 3,
                  icon = " ",
                  title = "Git Status",
                  cmd = "git --no-pager diff --stat -B -M -C",
                  height = 10,
                },
              }
            end,
            { section = "startup", padding = 1 },
            {
              section = "terminal",
              pane = 2,
              cmd = "pokemon-colorscripts -r --no-title; sleep .1",
              random = 10,
              indent = 13,
              height = 20,
              enabled = vim.fn.executable("pokemon-colorscripts") == 1,
            },
          },
        },
      }
    end,
    config = function(_, opts)
      require("snacks").setup(opts)
      vim.o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
    end,
    keys = {
      {
        "<c-`>",
        function()
          Snacks.terminal.toggle()
        end,
        desc = "Toggle Terminal (bottom)",
      },
      {
        "<c-/>",
        function()
          Snacks.terminal()
        end,
        desc = "Toggle Terminal (floating)",
      },
      {
        "<c-_>",
        function()
          Snacks.terminal()
        end,
        desc = "Toggle Terminal (floating)",
      },
      {
        "<leader><space>",
        function()
          Snacks.picker.smart()
        end,
        desc = "Files (smart)",
      },
      {
        "<leader>gs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "Files (git status)",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
      },
      {
        "<leader>f/",
        function()
          Snacks.picker.search_history()
        end,
        desc = "Search history",
      },
      {
        "<leader>fc",
        function()
          Snacks.picker.command_history()
        end,
        desc = "Command history",
      },
      {
        "<leader>fh",
        function()
          Snacks.picker.help()
        end,
        desc = "Help pages",
      },
      {
        "<leader>fH",
        function()
          Snacks.picker.highlights()
        end,
        desc = "Highlights",
      },
      {
        "<leader>fii",
        function()
          Snacks.picker.icons()
        end,
        desc = "Icons",
      },
      {
        "<leader>fj",
        function()
          Snacks.picker.jumps()
        end,
        desc = "Jumps",
      },
      {
        "<leader>fn",
        function()
          Snacks.picker.notifications()
        end,
        desc = "Notifications",
      },
      {
        "<leader>fk",
        function()
          Snacks.picker.keymaps({ global = true, plugs = true, ["local"] = true })
        end,
        desc = "Keymaps",
      },
      {
        "<leader>gd",
        function()
          local git_base = require("bombeelu.git")
          local base_ref, merge_base = git_base.find_base_branch()

          local short = vim.trim(
            vim.system({ "git", "rev-parse", "--short", merge_base }, { text = true }):wait().stdout
              or merge_base:sub(1, 7)
          )

          Snacks.picker.git_diff({
            title = "Git Changes (vs " .. short .. ")",
            base = merge_base,
            group = true,
          })
        end,
        desc = "Git changes (vs base branch)",
      },
    },
  },

  {
    "dmtrKovalenko/fff.nvim",
    cond = function()
      return vim.g.vscode == nil
    end,
    event = "VeryLazy",
    build = function()
      require("fff.download").download_or_build_binary()
    end,
    keys = {
      {
        "<leader>ff",
        function()
          require("fff").find_files()
        end,
        desc = "Files",
      },
      {
        "<leader>/",
        function()
          require("fff").live_grep()
        end,
        desc = "Live Grep",
      },
    },
    config = function()
      vim.g.fff = { lazy_sync = true, debug = { enabled = false, show_scores = false } }

      -- :Pick command (unified picker interface)
      local custom_pickers = {
        {
          name = "files",
          callback = function()
            require("fff").find_files()
          end,
        },
        {
          name = "grep",
          callback = function()
            require("fff").live_grep()
          end,
        },
      }

      local function get_picker_names()
        local pickers = {}

        for _, picker in ipairs(custom_pickers) do
          table.insert(pickers, picker.name)
        end

        if Snacks and Snacks.picker and Snacks.picker.sources then
          for name, _ in pairs(Snacks.picker.sources) do
            table.insert(pickers, name)
          end
        end

        return pickers
      end

      vim.api.nvim_create_user_command("Pick", function(opts)
        local picker_name = opts.args

        if picker_name == "" then
          picker_name = "files"
        end

        for _, picker in ipairs(custom_pickers) do
          if picker.name == picker_name then
            picker.callback()
            return
          end
        end

        if Snacks and Snacks.picker then
          Snacks.picker(picker_name)
        else
          vim.notify("Picker not found: " .. picker_name, vim.log.levels.ERROR)
        end
      end, {
        nargs = "?",
        desc = "Open picker",
        complete = function(arg_lead, _, _)
          local pickers = get_picker_names()
          return vim.tbl_filter(function(name)
            return name:find(arg_lead, 1, true) == 1
          end, pickers)
        end,
      })
    end,
  },
}
