vim.g.bubbly_palette = {
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
  lightgrey = "#b1b1b1",
  darkgrey = "#23272e"
}

vim.g.bubbly_statusline = {
  "mode", "truncate", "path", "branch", "builtinlsp.diagnostic_count",
  "divisor", "filetype", "progress"
}

vim.g.bubbly_characters = {left = "", right = "", close = "x"}

vim.g.bubbly_symbols = {
  builtinlsp = {diagnostic_count = {error = "✘ %s", warning = "⚠ %s"}}
}

vim.g.bubbly_colors = {
  default = "red",

  mode = {
    normal = {background = "green", foreground = "background"},
    insert = "blue",
    visual = "red",
    visualblock = "red",
    command = "red",
    terminal = "blue",
    replace = "yellow",
    default = "white"
  }
}
