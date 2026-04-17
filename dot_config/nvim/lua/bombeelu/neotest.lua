local M = {}

function M.setup()
  local neotest = require("neotest")

  local commands = {
    last = {
      display = "Re-run last test",
      callback = function()
        neotest.run.run_last()
      end,
    },
    nearest = {
      display = "Run nearest test",
      callback = function()
        neotest.run.run()
      end,
    },
    debug_nearest = {
      display = "Debug nearest test",
      callback = function()
        neotest.run.run({ vim.fn.expand("%"), strategy = "dap" })
      end,
    },
    file = {
      display = "Run all tests in current file",
      callback = function()
        neotest.run.run(vim.fn.expand("%"))
      end,
    },
    stop = {
      display = "Stop nearest test",
      callback = function()
        neotest.run.stop()
      end,
    },
    summary = {
      display = "Toggle test summary",
      callback = function()
        neotest.summary.toggle()
      end,
    },
    output = {
      display = "Show test output",
      callback = function()
        neotest.output.open({ enter = true })
      end,
    },
    output_panel = {
      display = "Toggle output panel",
      callback = function()
        neotest.output_panel.toggle()
      end,
    },
  }

  local command_names = vim.tbl_keys(commands)

  vim.api.nvim_create_user_command("Test", function(opts)
    local arg = opts.fargs[1] or "nearest"

    if commands[arg] then
      commands[arg].callback()
    else
      vim.notify("Unknown command: " .. arg, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    complete = function()
      return command_names
    end,
  })

  vim.keymap.set("n", "[T", function()
    require("neotest").jump.prev()
  end, { desc = "Jump to previous test" })

  vim.keymap.set("n", "]T", function()
    require("neotest").jump.next()
  end, { desc = "Jump to next test" })
end

return M
