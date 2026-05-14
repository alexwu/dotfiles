local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({
  { src = gh("nvim-neotest/nvim-nio") },
  { src = gh("antoinemadec/FixCursorHold.nvim") },
  { src = gh("nvim-neotest/neotest") },
})

local opts = {
  log_level = vim.log.levels.WARN,
  adapters = {},
  icons = {
    passed = " ✔",
    running = " ",
    failed = " ✖",
    skipped = " ﰸ",
    unknown = " ?",
  },
  status = { virtual_text = false },
  output = { open_on_run = true },
}

-- Adapter wiring (from main config plugins/neotest.lua)
if opts.adapters then
  local adapters = {}
  for name, config in pairs(opts.adapters or {}) do
    if type(name) == "number" then
      if type(config) == "string" then
        config = require(config)
      end
      adapters[#adapters + 1] = config
    elseif config ~= false then
      local adapter = require(name)
      if type(config) == "table" and not vim.tbl_isempty(config) then
        local meta = getmetatable(adapter)
        if adapter.setup then
          adapter.setup(config)
        elseif meta and meta.__call then
          adapter(config)
        else
          error("Adapter " .. name .. " does not support setup")
        end
      end
      adapters[#adapters + 1] = adapter
    end
  end
  opts.adapters = adapters
end

require("neotest").setup(opts)

-- Wire up the previously-orphaned bombeelu.neotest module
require("bombeelu.neotest").setup()

local set = _G.set
set("n", "<leader>tf", function()
  require("neotest").run.run(vim.fn.expand("%"))
end, { desc = "Run all tests in file" })

set("n", "<leader>ta", function()
  require("neotest").run.run(vim.loop.cwd())
end, { desc = "Run all test files" })

set("n", "<leader>tn", function()
  require("neotest").run.run()
end, { desc = "Run nearest test" })

set("n", "<leader>ts", function()
  require("neotest").summary.toggle()
end, { desc = "Toggle test summary" })

set("n", "<leader>to", function()
  require("neotest").output.open({ enter = true, auto_close = true })
end, { desc = "Show test output" })

set("n", "<leader>tO", function()
  require("neotest").output_panel.toggle()
end, { desc = "Toggle output panel" })

set("n", "<leader>tS", function()
  require("neotest").run.stop()
end, { desc = "Stop running tests" })

set("n", "<leader>tl", function()
  require("neotest").run.run_last()
end, { desc = "Re-run the last test" })
