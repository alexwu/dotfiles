local nnoremap = require("astronauta.keymap").nnoremap

local function prettier()
  return {
    exe = "prettier",
    args = { "--stdin", "--stdin-filepath", vim.api.nvim_buf_get_name(0) },
    stdin = true,
  }
end

local function rustfmt()
  return { exe = "rustfmt", args = { "--emit=stdout" }, stdin = true }
end

local function gofmt()
  return { exe = "gofmt", args = { "-s" }, stdin = true }
end

local function black()
  return { exe = "black", args = {}, stdin = true }
end

require("formatter").setup {
  logging = false,
  filetype = {
    typescript = { prettier },
    typescriptreact = { prettier },
    javascript = { prettier },
    javascriptreact = { prettier },
    go = { gofmt },
    graphql = { prettier },
    json = { prettier },
    jsonc = { prettier },
    html = { prettier },
    css = { prettier },
    ruby = { prettier },
    rust = { rustfmt },
    lua = {},
    python = { black },
  },
}

-- nnoremap({ "<Leader>y", ":Format<CR>" })
