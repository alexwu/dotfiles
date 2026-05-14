local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("dmtrKovalenko/fff.nvim") } })

vim.g.fff = {
  lazy_sync = true, -- start syncing only when the picker is open
  debug = {
    enabled = false,
    show_scores = false,
  },
}

local set = _G.set

set("n", "<leader>ff", function()
  require("fff").find_files()
end, { desc = "Files" })

set("n", "<leader>/", function()
  require("fff").live_grep()
end, { desc = "Live Grep" })

-- :Pick command — unified picker interface (fff + Snacks pickers)
local custom_pickers = {
  {
    name = "files",
    callback = function()
      require("fff").find_files()
    end,
  },
  {
    name = "grep",
    callback = function()
      require("fff").live_grep()
    end,
  },
}

local function get_picker_names()
  local pickers = {}

  for _, picker in ipairs(custom_pickers) do
    table.insert(pickers, picker.name)
  end

  if Snacks and Snacks.picker and Snacks.picker.sources then
    for name, _ in pairs(Snacks.picker.sources) do
      table.insert(pickers, name)
    end
  end

  return pickers
end

vim.api.nvim_create_user_command("Pick", function(opts)
  local picker_name = opts.args

  if picker_name == "" then
    picker_name = "files"
  end

  for _, picker in ipairs(custom_pickers) do
    if picker.name == picker_name then
      picker.callback()
      return
    end
  end

  if Snacks and Snacks.picker then
    Snacks.picker(picker_name)
  else
    vim.notify("Picker not found: " .. picker_name, vim.log.levels.ERROR)
  end
end, {
  nargs = "?",
  desc = "Open picker",
  complete = function(arg_lead, _, _)
    local pickers = get_picker_names()
    return vim.tbl_filter(function(name)
      return name:find(arg_lead, 1, true) == 1
    end, pickers)
  end,
})
