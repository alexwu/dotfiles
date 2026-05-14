-- Bundles nvim-treesitter + treesitter-context + treesitter-textobjects.
-- These are tight dependencies: textobjects and context both require nvim-treesitter
-- to be loaded first. Keeping them in one file makes the load order explicit.

-- Custom predicate for mise config file detection (used by queries/toml/injections.scm).
-- Register BEFORE plugin load so it's ready for first parse.
require("vim.treesitter.query").add_predicate("is-mise?", function(_, _, bufnr, _)
  local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
  local filename = vim.fn.fnamemodify(filepath, ":t")
  return string.match(filename, ".*mise.*%.toml$") ~= nil
end, { force = true, all = false })

-- Per-session caches. Declared early so both PackChanged (which invalidates
-- available_set after an update) and the FileType autocmd (which reads them)
-- close over the same upvalues.
local available_set
local install_attempted = {}

-- Custom papyrus parser registration. Fires on every nvim-treesitter update().
-- Registered BEFORE vim.pack.add so it's in place when the PackChanged install
-- hook below runs update() on first-ever install.
vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
    require("nvim-treesitter.parsers").papyrus = {
      install_info = {
        path = "~/Code/tree-sitter-papyrus/",
        branch = "dev",
        generate = true,
        generate_from_json = false,
        queries = "queries",
      },
    }
  end,
})

-- :TSUpdate as a build step, driven by vim.pack lifecycle.
-- Fires when nvim-treesitter itself installs or updates; refreshes parsers +
-- queries to match the new manifest. Must be registered BEFORE vim.pack.add()
-- so the very first install triggers it.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("bu.treesitter_pack_hooks", { clear = true }),
  callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name ~= "nvim-treesitter" then
      return
    end
    if kind ~= "install" and kind ~= "update" then
      return
    end

    -- Defer: install events fire BEFORE the plugin is loaded and BEFORE our
    -- setup() call below. Schedule onto the next tick so setup() wins.
    vim.schedule(function()
      if not ev.data.active then
        pcall(vim.cmd.packadd, "nvim-treesitter")
      end
      local ok, ts = pcall(require, "nvim-treesitter")
      if not ok then
        return
      end
      -- update() is a no-op for parsers that aren't installed yet, so a fresh
      -- install doesn't suddenly pull every parser. Existing parsers get bumped
      -- to whatever revision the new manifest specifies.
      ts.update(nil, { summary = true })
      -- Manifest may have new languages; force the cache to rebuild.
      available_set = nil
    end)
  end,
})

vim.pack.add({
  { src = gh("nvim-treesitter/nvim-treesitter") },
  { src = gh("nvim-treesitter/nvim-treesitter-textobjects"), version = "main" },
  { src = gh("nvim-treesitter/nvim-treesitter-context") },
})

-- Auto-install tree-sitter CLI on first run if missing
if vim.fn.executable("tree-sitter") == 0 then
  vim.notify("tree-sitter CLI not found, installing...", vim.log.levels.INFO)

  local install_cmd
  if vim.fn.has("win32") == 1 then
    install_cmd = { "scoop", "install", "tree-sitter" }
  elseif vim.fn.has("mac") == 1 then
    install_cmd = { "brew", "install", "tree-sitter" }
  else
    -- Linux fallback — npm is the most universal
    install_cmd = { "npm", "install", "-g", "tree-sitter-cli" }
  end

  vim.system(install_cmd, { text = true }, function(obj)
    if obj.code == 0 then
      vim.notify("tree-sitter CLI installed successfully!", vim.log.levels.INFO)
    else
      vim.notify(
        "Failed to install tree-sitter CLI. Please install manually:\n"
          .. "  Windows: scoop install tree-sitter\n"
          .. "  macOS: brew install tree-sitter\n"
          .. "  Linux: npm install -g tree-sitter-cli",
        vim.log.levels.WARN
      )
    end
  end)
end

require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

-- Manual modules: highlight + indent + fold via FileType autocmd.
-- Per treesitter-modules.nvim README, post-0.12 incremental selection is native via an/in.

-- Cache the upstream parser manifest so we only ask once per session.
-- Without this gate, every FileType for a language nvim-treesitter doesn't ship
-- (random filetypes, vendor stuff, etc.) hits install() and spams warnings.
local function is_available(language)
  if not available_set then
    available_set = {}
    local ok, langs = pcall(require("nvim-treesitter").get_available)
    if ok and langs then
      for _, lang in ipairs(langs) do
        available_set[lang] = true
      end
    end
  end
  return available_set[language] == true
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("bu.treesitter_setup", { clear = true }),
  callback = function(args)
    local buf = args.buf
    local language = vim.treesitter.language.get_lang(args.match) or args.match

    if not vim.treesitter.language.add(language) then
      -- Parser not on runtimepath. Only try to install if it's a known parser
      -- AND we haven't already attempted it this session.
      if install_attempted[language] then
        return
      end
      install_attempted[language] = true
      if not is_available(language) then
        return
      end
      pcall(require("nvim-treesitter").install, { language })
      return
    end

    -- fold (per-window)
    vim.wo.foldmethod = "expr"
    vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    -- highlight
    vim.treesitter.start(buf, language)
    -- indent
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})
