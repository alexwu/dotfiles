vim.pack.add({ { src = gh("mfussenegger/nvim-lint") } })

local lint = require("lint")

local linters_by_ft = {
  lua = { "selene" },
  gdscript = { "gdlint" },
  swift = { "swiftlint" },
  [".*/.github/workflows/.*%.yml"] = "yaml.ghaction",
}

---@type table<string, table>
local linter_overrides = {
  selene = {
    condition = function(ctx)
      return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
    end,
  },
  swiftlint = {
    condition = function(ctx)
      return vim.fs.find({ ".swiftlint.yml" }, { path = ctx.filename, upward = true })[1]
    end,
  },
}

for name, linter in pairs(linter_overrides) do
  if type(linter) == "table" and type(lint.linters[name]) == "table" then
    lint.linters[name] = vim.tbl_deep_extend("force", lint.linters[name], linter)
  else
    lint.linters[name] = linter
  end
end
lint.linters_by_ft = linters_by_ft

local function debounce(ms, fn)
  local timer = vim.uv.new_timer()
  return function(...)
    local argv = { ... }
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(unpack(argv))
    end)
  end
end

local function do_lint()
  local names = lint._resolve_linter_by_ft(vim.bo.filetype)

  if #names == 0 then
    vim.list_extend(names, lint.linters_by_ft["_"] or {})
  end

  vim.list_extend(names, lint.linters_by_ft["*"] or {})

  local ctx = { filename = vim.api.nvim_buf_get_name(0) }
  ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
  names = vim.tbl_filter(function(name)
    local linter = lint.linters[name]
    if not linter then
      vim.notify("Linter not found: " .. name, vim.log.levels.WARN)
    end
    return linter and not (type(linter) == "table" and linter.condition and not linter.condition(ctx))
  end, names)

  if #names > 0 then
    lint.try_lint(names)
  end
end

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
  callback = debounce(100, do_lint),
})
