return {
  {
    "saghen/blink.cmp",
    version = "*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    opts_extend = {
      "sources.completion.enabled_providers",
      "sources.compat",
      "sources.default",
    },
    opts = {
      fuzzy = {
        prebuilt_binaries = {
          download = true,
        },
      },
      keymap = {
        preset = "super-tab",
        ["<CR>"] = { "accept", "fallback" },
        ["<C-e>"] = { "cancel", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
      },
      completion = {
        accept = {
          auto_brackets = { enabled = true },
        },
        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },
        menu = {
          border = "rounded",
          draw = {
            columns = { { "label" }, { "kind_icon", "kind", "source_name", gap = 1 } },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 0,
          window = {
            border = "rounded",
          },
        },
        ghost_text = { enabled = true },
      },
      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant = "mono",
      },
      signature = {
        enabled = true,
        window = {
          border = "rounded",
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "cursortab" },
        providers = {
          cursortab = {
            module = "cursortab.blink",
            name = "cursortab",
            async = true,
            -- Should match provider.completion_timeout in cursortab config
            timeout_ms = 5000,
            score_offset = 50, -- Higher priority among suggestions
          },
        },
      },
    },
  },
  {
    "saghen/blink.pairs",
    version = "*",
    event = "InsertEnter",
  },
  {
    "saghen/blink.indent",
    event = "BufReadPost",
    cond = function()
      return vim.g.vscode == nil
    end,
  },
}
