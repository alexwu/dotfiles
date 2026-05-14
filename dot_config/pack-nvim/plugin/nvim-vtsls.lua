-- DirChanged-deferred: only load vtsls when in a TypeScript project (tsconfig.json present).
-- Mirrors main config's lazy.load() pattern but uses vim.pack.add (sync, idempotent).
local loaded = false
local set = _G.set

local function check()
  if loaded then
    return
  end
  if vim.fs.root(0, { "tsconfig.json" }) then
    vim.pack.add({ { src = gh("yioneko/nvim-vtsls") } })

    set("n", "gD", function()
      require("vtsls").commands.goto_source_definition(0)
    end, { desc = "Goto Source Definition" })
    set("n", "<leader>co", function()
      require("vtsls").commands.organize_imports(0)
    end, { desc = "Organize Imports" })
    set("n", "gro", function()
      require("vtsls").commands.organize_imports(0)
    end, { desc = "Organize Imports" })
    set("n", "<leader>cM", function()
      require("vtsls").commands.add_missing_imports(0)
    end, { desc = "Add missing imports" })
    set("n", "<leader>cu", function()
      require("vtsls").commands.remove_unused_imports(0)
    end, { desc = "Remove unused imports" })
    set("n", "gru", function()
      require("vtsls").commands.remove_unused_imports(0)
    end, { desc = "Remove unused imports" })
    set("n", "<leader>cU", function()
      require("vtsls").commands.remove_unused(0)
    end, { desc = "Remove unused" })
    set("n", "grU", function()
      require("vtsls").commands.remove_unused(0)
    end, { desc = "Remove unused" })

    loaded = true
  end
end

check() -- startup check (cwd at startup)

vim.api.nvim_create_autocmd("DirChanged", {
  group = require("bu").nvim.augroup("vtsls.custom"),
  callback = check,
})
