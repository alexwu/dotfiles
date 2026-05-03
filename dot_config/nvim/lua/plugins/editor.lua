local utils = require("bombeelu.utils")

return {
  { "nvim-lua/plenary.nvim", lazy = true },
  { "alexwu/bu", dev = true },

  -- mini.icons
  {
    "nvim-mini/mini.icons",
    lazy = false,
    config = function()
      require("mini.icons").setup({})
      MiniIcons.mock_nvim_web_devicons()
    end,
  },

  -- mini.surround
  {
    "nvim-mini/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "ys",
        delete = "ds",
        find = "",
        find_left = "",
        highlight = "",
        replace = "cs",
        update_n_lines = "",
      },
      search_method = "cover_or_next",
    },
  },

  -- mini.splitjoin
  {
    "nvim-mini/mini.splitjoin",
    event = "VeryLazy",
    opts = {},
  },

  -- mini.ai
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    config = function()
      local ai = require("mini.ai")
      ai.setup({
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }, {}),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" },
          d = { "%f[%d]%d+" },
          e = {
            {
              "%u[%l%d]+%f[^%l%d]",
              "%f[%S][%l%d]+%f[^%l%d]",
              "%f[%P][%l%d]+%f[^%l%d]",
              "^[%l%d]+%f[^%l%d]",
            },
            "^().*()$",
          },
          g = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line("$"),
              col = math.max(vim.fn.getline("$"):len(), 1),
            }
            return { from = from, to = to }
          end,
          u = ai.gen_spec.function_call(),
          U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }),
        },
      })
    end,
  },

  -- mini.align
  {
    "nvim-mini/mini.align",
    event = "VeryLazy",
    opts = {},
  },

  -- nvim-spider
  {
    "chrisgrieser/nvim-spider",
    event = "VeryLazy",
    config = function()
      require("spider").setup({
        skipInsignificantPunctuation = false,
      })

      local map = vim.keymap.set
      map(
        { "n", "o", "x" },
        "w",
        "<cmd>lua require('spider').motion('w')<CR>",
        { desc = "[count] words forward (subword)" }
      )
      map(
        { "n", "o", "x" },
        "e",
        "<cmd>lua require('spider').motion('e')<CR>",
        { desc = "Forward to end of word [count] (subword)" }
      )
      map(
        { "n", "o", "x" },
        "b",
        "<cmd>lua require('spider').motion('b')<CR>",
        { desc = "[count] words backward (subword)" }
      )
    end,
  },

  -- flash.nvim
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      search = {
        multi_window = false,
        forward = false,
      },
      jump = {
        autojump = true,
      },
      modes = {
        search = {
          enabled = false,
        },
        char = {
          enabled = false,
          jump_labels = true,
          search = { wrap = false },
          highlight = { backdrop = false },
          multi_line = false,
          jump = {
            register = false,
            autojump = true,
          },
        },
      },
    },
    keys = {
      {
        "s",
        function()
          require("flash").jump({ search = { forward = true, wrap = false, multi_window = false } })
        end,
        mode = { "n", "x" },
        desc = "Jump to pattern (forward)",
      },
      {
        "S",
        function()
          require("flash").jump({ search = { forward = false, wrap = false, multi_window = false } })
        end,
        mode = { "n", "x" },
        desc = "Jump to pattern (backward)",
      },
      {
        "r",
        function()
          require("flash").remote()
        end,
        mode = "o",
        desc = "Remote Flash",
      },
      {
        "R",
        function()
          require("flash").treesitter_search()
        end,
        mode = { "o", "x" },
        desc = "Treesitter Search",
      },
    },
  },

  -- grug-far.nvim
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = { engine = "ripgrep" },
  },

  -- dial.nvim
  {
    "monaqa/dial.nvim",
    event = "VeryLazy",
    config = function()
      local augend = require("dial.augend")

      require("dial.config").augends:register_group({
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.decimal_int,
          augend.constant.alias.bool,
          augend.constant.new({
            elements = { "and", "or" },
            word = true,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "&&", "||" },
            word = false,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "it", "fit", "xit" },
            word = true,
            cyclic = true,
          }),
          augend.constant.new({
            elements = { "enable", "disable" },
            word = true,
            cyclic = true,
          }),
        },
        typescript = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.constant.new({ elements = { "var", "let", "const" } }),
        },
      })

      local map = vim.keymap.set
      map("n", "<C-a>", function()
        require("dial.map").manipulate("increment", "normal")
      end, { desc = "Increment number/boolean/constant" })

      map("n", "<C-x>", function()
        require("dial.map").manipulate("decrement", "normal")
      end, { desc = "Decrement number/boolean/constant" })

      map("v", "<C-a>", function()
        require("dial.map").manipulate("increment", "visual")
      end, { desc = "Increment selection" })

      map("v", "<C-x>", function()
        require("dial.map").manipulate("decrement", "visual")
      end, { desc = "Decrement selection" })
    end,
  },

  -- yazi.nvim
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    event = "VeryLazy",
    cond = utils.not_vscode,
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    keys = {
      {
        "<leader>-",
        "<cmd>Yazi<cr>",
        mode = { "n", "v" },
        desc = "Open yazi at the current file",
      },
      {
        "<leader>cw",
        "<cmd>Yazi cwd<cr>",
        desc = "Open yazi in nvim's working directory",
      },
      {
        "<c-up>",
        "<cmd>Yazi toggle<cr>",
        desc = "Resume the last yazi session",
      },
    },
    ---@type YaziConfig | {}
    opts = {
      open_for_directories = false,
      keymaps = {
        show_help = "<f1>",
      },
    },
  },

  -- oil.nvim
  {
    -- "stevearc/oil.nvim",
    "barrettruth/canola.nvim",
    branch = "main",
    lazy = false,
    name = "oil",
    cond = utils.not_vscode,
    keys = {
      { "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
    },
    opts = {
      default_file_explorer = true,
      win_options = {
        signcolumn = "yes:2",
      },
      delete_to_trash = true,
      watch_for_changes = true,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ["<C-s>"] = false,
        ["<C-h>"] = false,
        ["<C-t>"] = false,
        ["<C-l>"] = false,
      },
    },
  },

  -- guess-indent.nvim
  {
    "NMAC427/guess-indent.nvim",
    event = "BufReadPre",
    opts = {},
  },

  -- conform.nvim
  {
    "stevearc/conform.nvim",
    lazy = false,
    opts = {
      formatters_by_ft = {
        ["markdown.mdx"] = { "oxfmt", "prettier" },
        c = { "clang_format" },
        cmake = { "cmake_format" },
        cpp = { "clang_format" },
        css = { "oxfmt", "prettier" },
        eruby = { "rustywind" },
        go = { "gofmt" },
        graphql = { "prettier" },
        gdscript = { "gdformat" },
        handlebars = { "prettier" },
        html = { "oxfmt", "prettier" },
        javascript = { "oxfmt", "prettier" },
        javascriptreact = { "oxfmt", "prettier" },
        json = { "oxfmt", "prettier", stop_after_first = true },
        jsonc = { "oxfmt", "prettier" },
        just = { "just" },
        less = { "prettier" },
        lua = { "stylua" },
        liquid = { "prettier" },
        markdown = { "oxfmt", "prettier" },
        nim = { "nph" },
        python = { "ruff" },
        ruby = { "rubyfmt", "syntax_tree", stop_after_first = true },
        rust = { "rustfmt" },
        scss = { "oxfmt", "prettier" },
        sql = { "sqruff" },
        toml = { "taplo" },
        typescript = { "oxfmt", "biome", "prettier", stop_after_first = true },
        typescriptreact = { "oxfmt", "prettier" },
        vue = { "oxfmt", "prettier" },
        yaml = { "oxfmt", "prettier" },
        swift = { "swift", "swiftformat", stop_after_first = true },
        xml = { "xmlformatter" },
        zig = { "zigfmt" },
      },
    },
    config = function(_, opts)
      require("conform").setup(opts)

      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

      local set = _G.set or vim.keymap.set

      set("n", { "<F8>", "gq" }, function()
        require("conform").format({ bufnr = vim.api.nvim_get_current_buf(), async = false })
      end, { silent = true, desc = "Format buffer" })

      set("i", "<F8>", function()
        require("conform").format({ bufnr = vim.api.nvim_get_current_buf(), async = true })
      end, { silent = true, desc = "Format buffer" })

      vim.api.nvim_create_user_command("Format", function(args)
        local range = nil
        if args.count ~= -1 then
          local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
          range = {
            start = { args.line1, 0 },
            ["end"] = { args.line2, end_line:len() },
          }
        end

        local formatter = args.args ~= "" and { args.args } or nil
        require("conform").format({
          async = true,
          lsp_fallback = "fallback",
          range = range,
          formatters = formatter,
        })
      end, {
        range = true,
        nargs = "?",
        desc = "Format buffer with optional formatter",
        complete = function(arg_lead, _, _)
          local conform = require("conform")
          local formatters = conform.list_formatters(0)

          local formatter_names = {}
          for _, formatter in ipairs(formatters) do
            table.insert(formatter_names, formatter.name)
          end

          return vim.tbl_filter(function(name)
            return name:find(arg_lead, 1, true) == 1
          end, formatter_names)
        end,
      })
    end,
  },

  -- vim-repeat
  {
    "tpope/vim-repeat",
    event = "VeryLazy",
  },

  -- chezmoi
  {
    "alker0/chezmoi.vim",
    init = function()
      vim.g["chezmoi#use_tmp_buffer"] = 1
      vim.g["chezmoi#source_dir_path"] = vim.uv.os_homedir() .. "/.local/share/chezmoi"
    end,
  },
  -- Strip trailing whitespace on edited lines
  { "lewis6991/spaceless.nvim", event = "InsertEnter", opts = {} },

  -- Open file:line format (e.g., nvim foo.lua:10)
  { "lewis6991/fileline.nvim", lazy = false },

  {
    "xvzc/chezmoi.nvim",
    opts = {
      edit = {
        watch = false,
        force = false,
      },
      notification = {
        on_open = true,
        on_apply = true,
        on_watch = false,
      },
      telescope = {
        select = { "<CR>" },
      },
    },
    init = function()
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { vim.uv.os_homedir() .. "/.local/share/chezmoi/*" },
        callback = function()
          vim.schedule(require("chezmoi.commands.__edit").watch)
        end,
      })
    end,
  },

  {
    "cursortab/cursortab.nvim",
    -- version = "*",
    lazy = false,
    build = "cd server && go build",
    cond = utils.not_vscode,
    opts = {
      ui = {
        completions = {
          fg_opacity = 0.8,
        },
      },
      provider = {
        -- type = "sweep",
        type = "zeta-2",
        url = "http://localhost:8000",
        -- model = "sweepai/sweep-next-edit-1.5b",
        -- model = "henrik3/sweep-next-edit-v2-7B",
        model = "zed-industries/zeta-2",
      },
      keymaps = {
        -- accept = false,
        accept = "<C-y>",
      },
      blink = {
        enabled = false,
        ghost_text = true,
      },
    },
  },
}
