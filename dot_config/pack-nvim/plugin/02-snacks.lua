local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("folke/snacks.nvim") } })

-- Compute "in_git" before calling setup so the dashboard sections can use it.
-- vim.fs.root walks up from cwd to find a .git ancestor.
local in_git = vim.fs.root(vim.uv.cwd() or ".", ".git") ~= nil

require("snacks").setup({
  input = {},
  gitbrowse = {},
  notifier = {},
  statuscolumn = {},
  picker = {
    enabled = true,
    win = {
      input = {
        keys = {
          ["<Esc>"] = { "close", mode = { "n", "i" } },
          ["<c-u>"] = { "clear_input", mode = { "i" } },
        },
      },
    },
    actions = {
      clear_input = function(picker)
        picker.input:set("")
      end,
    },
  },
  dashboard = {
    preset = {
      pick = nil,
      keys = {
        { icon = " ", key = "f", desc = "Find File", action = ":lua require('fff').find_files()" },
        { icon = " ", key = "/", desc = "Grep", action = ":lua require('fff').live_grep()" },
        { icon = " ", key = "d", desc = "Diff HEAD", action = ":DiffviewOpen", enabled = in_git },
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      },
    },
    sections = {
      { section = "keys", gap = 1, padding = 1 },
      { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1, enabled = not in_git },
      function()
        return {
          {
            pane = 1,
            section = "terminal",
            enabled = in_git,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
            icon = " ",
            title = "Git Status",
            cmd = "git --no-pager diff --stat -B -M -C",
            height = 10,
          },
        }
      end,
      -- { section = "startup", padding = 1 },
      {
        section = "terminal",
        pane = 2,
        cmd = "pokemon-colorscripts -r --no-title; sleep .1",
        random = 10,
        indent = 13,
        height = 20,
        enabled = vim.fn.executable("pokemon-colorscripts") == 1,
      },
    },
  },
})

vim.o.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]

Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.diagnostics():map("<leader>ud")

local set = _G.set

set({ "n", "t" }, "<c-`>", function()
  Snacks.terminal.toggle()
end, { desc = "Toggle Terminal (bottom)" })

set({ "n", "t" }, "<c-/>", function()
  Snacks.terminal()
end, { desc = "Toggle Terminal (floating)" })

set({ "n", "t" }, "<c-_>", function()
  Snacks.terminal()
end, { desc = "Toggle Terminal (floating)" })

set("n", "<leader><space>", function()
  Snacks.picker.smart({
    layout = {
      layout = {
        box = "horizontal",
        width = 0.8,
        min_width = 120,
        height = 0.8,
        {
          box = "vertical",
          border = true,
          title = "{title} {live} {flags}",
          { win = "list", border = "none" },
          { win = "input", height = 1, border = "top" },
        },
        { win = "preview", title = "{preview}", border = true, width = 0.5 },
      },
    },
  })
end, { desc = "Files (smart)" })

set("n", "<leader>gs", function()
  Snacks.picker.git_status()
end, { desc = "Files (git status)" })

set("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Buffers" })

set("n", "<leader>f/", function()
  Snacks.picker.search_history()
end, { desc = "Search history" })

set("n", "<leader>fc", function()
  Snacks.picker.command_history()
end, { desc = "Command history" })

set("n", "<leader>fh", function()
  Snacks.picker.help()
end, { desc = "Help pages" })

set("n", "<leader>fH", function()
  Snacks.picker.highlights()
end, { desc = "Highlights" })

set("n", "<leader>fii", function()
  Snacks.picker.icons()
end, { desc = "Icons" })

set("n", "<leader>fj", function()
  Snacks.picker.jumps()
end, { desc = "Jumps" })

set("n", "<leader>fn", function()
  Snacks.picker.notifications()
end, { desc = "Notifications" })

set("n", "<leader>fk", function()
  Snacks.picker.keymaps({ global = true, plugs = true, ["local"] = true })
end, { desc = "Keymaps" })

set("n", "<leader>gg", function()
  local git_base = require("bombeelu.git")
  local _, merge_base = git_base.find_base_branch()

  local short = vim.trim(
    vim.system({ "git", "rev-parse", "--short", merge_base }, { text = true }):wait().stdout or merge_base:sub(1, 7)
  )

  Snacks.picker.git_diff({
    title = "Git Changes (vs " .. short .. ")",
    base = merge_base,
    group = true,
  })
end, { desc = "Git changes (vs base branch)" })
