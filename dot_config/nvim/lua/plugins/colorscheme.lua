return {
  { "rktjmp/lush.nvim", lazy = true },
  {
    "alexwu/nvim-snazzy",
    dependencies = { "rktjmp/lush.nvim" },
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("snazzy")
    end,
  },
}
