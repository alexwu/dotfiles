vim.pack.add({ { src = gh("stevearc/conform.nvim") } })

require("conform").setup({
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
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

local set = _G.set

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
