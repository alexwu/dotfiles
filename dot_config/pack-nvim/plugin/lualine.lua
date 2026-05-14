local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("nvim-lualine/lualine.nvim") } })

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
    section_separators = { left = "", right = "" },
    globalstatus = true,
  },
  -- Drop "lazy" — we use vim.pack now
  extensions = { "quickfix", "oil", "overseer", "man", "mason" },
  sections = {
    lualine_a = {
      { "mode", separator = {}, right_padding = 2 },
    },
    lualine_b = {
      { "branch", color = { fg = "#3a3d4d", bg = "#f1f1f0" }, separator = { right = "" } },
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
        symbols = { error = " ", warn = " ", info = " ", hint = " " },
        colored = true,
        update_in_insert = false,
        always_visible = false,
      },
    },
    lualine_x = {
      Snacks and Snacks.profiler and Snacks.profiler.status() or "",
      -- noice mode display dropped (noice omitted from this config)
      -- lazy.status updates dropped (we use vim.pack — :Pack info instead)
      {
        "diff",
        symbols = {
          added = " ",
          modified = " ",
          removed = " ",
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
