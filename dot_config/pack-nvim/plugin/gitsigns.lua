local utils = require("bombeelu.utils")
if not utils.not_vscode then
  return
end

vim.pack.add({ { src = gh("lewis6991/gitsigns.nvim") } })

require("gitsigns").setup({
  sign_priority = 6,
  attach_to_untracked = true,
  current_line_blame = true,
  current_line_blame_opts = {
    virt_text = false,
    virt_text_pos = "eol",
    delay = 500,
  },
  preview_config = { border = "rounded" },
  current_line_blame_formatter = " <author>, <author_time:%R> • <summary> ",
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    map("n", "]c", function()
      if vim.wo.diff then
        return "]c"
      end
      vim.schedule(function()
        gs.next_hunk({ navigation_message = false, preview = false })
      end)
      return "<Ignore>"
    end, { expr = true, desc = "Next Git hunk" })

    map("n", "[c", function()
      if vim.wo.diff then
        return "[c"
      end
      vim.schedule(function()
        gs.prev_hunk({ navigation_message = false, preview = false })
      end)
      return "<Ignore>"
    end, { expr = true, desc = "Previous Git hunk" })

    map("n", "gssh", gs.stage_hunk, { desc = "Stage hunk" })
    map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
    map({ "n", "v" }, "gsrh", gs.reset_hunk, { desc = "Reset hunk" })
    map({ "n", "v" }, "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
    map("n", "gsuh", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
    map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage hunk" })
    map("n", "gssb", gs.stage_buffer, { desc = "Stage buffer" })
    map("n", "<leader>hb", gs.stage_buffer, { desc = "Stage buffer" })
    map("n", "gsrb", gs.reset_buffer, { desc = "Reset buffer" })
    map("n", "<leader>hR", gs.reset_buffer, { desc = "Reset buffer" })
    map("n", "gM", function()
      gs.blame_line({ full = true, ignore_whitespace = true })
    end, { desc = "Git blame" })
    map("n", "gsdh", function()
      gs.diffthis()
    end, { desc = "Git diff" })
    map("n", "ghD", function()
      gs.diffthis("~")
    end, { desc = "Git diff ~" })
    map("n", "M", gs.preview_hunk, { desc = "Preview hunk" })
    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Inner Git hunk" })
  end,
})
