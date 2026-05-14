-- linw1995/nvim-mcp — exposes Neovim state to MCP clients via an RPC server.
-- The Lua plugin is just glue; the heavy lifting is a Rust binary the user
-- runs as the actual MCP server (e.g. `claude mcp add ... -- nvim-mcp ...`).
--
-- Build step: `cargo install --path .` against the plugin directory installs
-- the `nvim-mcp` binary to ~/.cargo/bin. vim.pack has no native `build` field,
-- so we drive the build off the PackChanged lifecycle. Must be registered
-- BEFORE vim.pack.add() so first-install fires it.

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("bu.nvim_mcp_build", { clear = true }),
  callback = function(ev)
    if ev.data.spec.name ~= "nvim-mcp" then
      return
    end
    if ev.data.kind ~= "install" and ev.data.kind ~= "update" then
      return
    end

    if vim.fn.executable("cargo") == 0 then
      vim.notify("nvim-mcp: cargo not found — install the Rust toolchain or build manually", vim.log.levels.WARN)
      return
    end

    vim.notify("nvim-mcp: cargo install --path . ...", vim.log.levels.INFO)
    vim.system({ "cargo", "install", "--path", "." }, { cwd = ev.data.path, text = true }, function(obj)
      if obj.code == 0 then
        vim.notify("nvim-mcp: build complete", vim.log.levels.INFO)
      else
        vim.notify(
          "nvim-mcp: build failed (exit " .. tostring(obj.code) .. ")\n" .. (obj.stderr or ""),
          vim.log.levels.ERROR
        )
      end
    end)
  end,
})

vim.pack.add({ { src = gh("linw1995/nvim-mcp") } })

require("nvim-mcp").setup({})
