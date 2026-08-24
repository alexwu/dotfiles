require("vim._core.ui2").enable({
  msg = {
    targets = {
      default = "cmd",
      progress = "msg",
      emsg = "msg",
      wmsg = "msg",
      lua_error = "msg",
      rpc_error = "msg",
    },
  },
})

vim.pack.add({ "https://github.com/rachartier/tiny-cmdline.nvim" })

require("tiny-cmdline").setup({
  on_reposition = require("tiny-cmdline").adapters.blink,
})
