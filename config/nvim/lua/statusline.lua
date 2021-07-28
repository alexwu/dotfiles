local snazzy = function()
  local colors = {
    background = "#3a3d4d",
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
    darkgray = "#3a3d4d"
  }

  return {
    normal = {
      a = {bg = colors.blue, fg = colors.black, gui = "bold"},
      b = {bg = colors.lightgray, fg = colors.white},
      c = {bg = colors.darkgray, fg = colors.lightgray}
    },
    insert = {
      a = {bg = colors.green, fg = colors.black, gui = "bold"},
      b = {bg = colors.lightgray, fg = colors.white},
      c = {bg = colors.darkgray, fg = colors.lightgray}
    },
    visual = {
      a = {bg = colors.purple, fg = colors.black, gui = "bold"},
      b = {bg = colors.lightgray, fg = colors.white},
      c = {bg = colors.darkgray, fg = colors.lightgray}
    },
    replace = {
      a = {bg = colors.red, fg = colors.black, gui = "bold"},
      b = {bg = colors.lightgray, fg = colors.white},
      c = {bg = colors.darkgray, fg = colors.lightgray}
    },
    command = {
      a = {bg = colors.yellow, fg = colors.black, gui = "bold"},
      b = {bg = colors.lightgray, fg = colors.white},
      c = {bg = colors.darkgray, fg = colors.lightgray}
    },
    inactive = {
      a = {bg = colors.darkgray, fg = colors.gray, gui = "bold"},
      b = {bg = colors.lightgray, fg = colors.gray},
      c = {bg = colors.darkgray, fg = colors.darkgray}
    }
  }
end

require("lualine").setup {
  options = {
    theme = snazzy(),
    disabled_filetypes = {},
    component_separators = {"", ""},
    section_separators = {"", ""}
  },
  extensions = {"fugitive", "nvim-tree", "quickfix"},
  sections = {
    lualine_a = {"mode"},
    lualine_b = {"branch"},
    lualine_c = {"filename"},
    lualine_x = {"encoding", "filetype"},
    lualine_y = {},
    lualine_z = {"location"}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {"filename"},
    lualine_x = {"location"},
    lualine_y = {},
    lualine_z = {}
  }
}
