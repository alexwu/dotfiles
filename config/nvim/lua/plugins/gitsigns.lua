require("gitsigns").setup {
  debug_mode = true,
  sign_priority = 6,
  attach_to_untracked = true,
  current_line_blame = false,
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = "eol",
    delay = 1000,
  },
  preview_config = { border = "rounded" },
  current_line_blame_formatter_opts = { relative_time = true },
  current_line_blame_formatter = function(name, blame_info, opts)
    if blame_info.author == name then
      blame_info.author = "You"
    end

    local text
    if blame_info.author == "Not Committed Yet" then
      text = blame_info.author
    else
      local date_time

      if opts.relative_time then
        date_time = require("gitsigns.util").get_relative_time(tonumber(blame_info["author_time"]))
      else
        date_time = os.date("%m/%d/%Y", tonumber(blame_info["author_time"]))
      end

      text = string.format("%s, %s • %s", blame_info.author, date_time, blame_info.summary)
    end

    return { { " " .. text, "GitSignsCurrentLineBlame" } }
  end,
  keymaps = {
    noremap = true,

    ["n <leader>sh"] = "<cmd>lua require\"gitsigns\".stage_hunk()<CR>",
    ["v <leader>sh"] = "<cmd>lua require\"gitsigns\".stage_hunk({vim.fn.line(\".\"), vim.fn.line(\"v\")})<CR>",
    ["n <leader>sb"] = "<cmd>lua require\"gitsigns\".stage_buffer()<CR>",
    ["n <leader>hr"] = "<cmd>lua require\"gitsigns\".reset_hunk()<CR>",
    ["v <leader>hr"] = "<cmd>lua require\"gitsigns\".reset_hunk({vim.fn.line(\".\"), vim.fn.line(\"v\")})<CR>",
    ["n <leader>hu"] = "<cmd>lua require\"gitsigns\".undo_stage_hunk()<CR>",
    ["n <leader>hb"] = "<cmd>lua require\"gitsigns\".reset_buffer()<CR>",
    ["n M"] = "<cmd>lua require\"gitsigns\".blame_line(false)<CR>",
  },
}
