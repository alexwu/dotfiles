local utils = require("bombeelu.utils")
if not utils.is_mac() then
  return
end

-- DirChanged-deferred: only load xcodebuild.nvim when in a Swift/Xcode project.
local loaded = false
local markers = { "*.xcodeproj", "*.xcworkspace", "Package.swift" }

local function find_project()
  local start = vim.uv.cwd() or vim.uv.os_homedir()
  return vim.fs.root(start, function(name)
    return vim.iter(markers):any(function(m)
      return vim.glob.to_lpeg(m):match(name) ~= nil
    end)
  end)
end

local function check()
  if loaded then
    return
  end
  if find_project() then
    vim.pack.add({
      { src = gh("wojciech-kulik/xcodebuild.nvim") },
    })
    require("xcodebuild").setup({
      integrations = {
        snacks_nvim = { enabled = true },
      },
    })
    loaded = true
  end
end

check()

vim.api.nvim_create_autocmd("DirChanged", {
  group = require("bu").nvim.augroup("bombeelu.xcode"),
  callback = check,
})
