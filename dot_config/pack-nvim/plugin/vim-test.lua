local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("vim-test/vim-test") } })

_G.snacks_test_strategy = function(cmd)
  Snacks.terminal.open(cmd, {
    interactive = false,
    auto_close = false,
    win = {
      position = "float",
      border = "rounded",
      width = 0.9,
      height = 0.9,
      keys = {
        q = "hide",
      },
    },
  })
end

vim.cmd([[
  function! SnacksTestStrategy(cmd)
    let g:test_cmd = a:cmd
    lua snacks_test_strategy(vim.g.test_cmd)
  endfunction

  let g:test#custom_strategies = {'snacks': function('SnacksTestStrategy')}
]])

vim.g["test#strategy"] = "snacks"
vim.g["test#ruby#rspec#executable"] = "bundle exec rspec"
vim.g["test#ruby#rspec#options"] = {
  file = "--format documentation --force-color",
  suite = "--format documentation --force-color",
  nearest = "--format documentation --force-color",
}
vim.g["test#javascript#jest#options"] = "--color=always"
vim.g["test#typescript#jest#options"] = "--color=always"

local set = _G.set
set("n", "<F7>", vim.cmd.TestNearest, { desc = "Run nearest test (vim-test)" })
set("n", "<F9>", vim.cmd.TestFile, { desc = "Run all tests in file (vim-test)" })
