return {
  {
    "wojciech-kulik/xcodebuild.nvim",
    lazy = true,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      local loaded = false
      local markers = {
        "*.xcodeproj",
        "*.xcworkspace",
        "Package.swift",
      }

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
          require("lazy").load({ plugins = { "xcodebuild.nvim" } })
          loaded = true
        end
      end

      check()

      vim.api.nvim_create_autocmd("DirChanged", {
        group = vim.api.nvim_create_augroup("bombeelu.xcode", { clear = true }),
        callback = check,
      })
    end,
    opts = {
      integrations = {
        snacks_nvim = { enabled = true },
      },
    },
  },
}
