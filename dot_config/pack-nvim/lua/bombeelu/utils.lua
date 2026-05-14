local M = {}

---@return boolean
function M.is_mac()
  return vim.fn.has("mac") == 1
end

---@return boolean
function M.is_windows()
  return vim.fn.has("win32") == 1
end

---@return boolean
function M.is_vscode()
  return vim.g.vscode ~= nil
end

---@generic T
---@param fn fun(): T
---@return fun(): boolean
function M.invert(fn)
  return function()
    return not fn()
  end
end

M.not_vscode = M.invert(M.is_vscode)

---@param modes string|string[]
---@param mappings string|string[]
---@param callback string|function
---@param opts? table
function M.set(modes, mappings, callback, opts)
  opts = opts or {}
  if type(mappings) == "string" then
    mappings = { mappings }
  end

  for _, mapping in ipairs(mappings) do
    vim.keymap.set(modes, mapping, callback, opts)
  end
end

-- ============================================================================
-- PLUGIN HELPERS (URL builders, status check) — exposed globally for plugin/*
-- ============================================================================
---@param name string Plugin name
---@return boolean
function M.is_active(name)
  local info = vim.pack.get({ name })
  return info[1] ~= nil and info[1].active
end

---@param repo string Repository in "user/repo" format
---@return string
function M.gh(repo)
  return "https://github.com/" .. repo
end

---@param repo string Repository in "user/repo" format
---@return string
function M.gl(repo)
  return "https://gitlab.com/" .. repo
end

---@param repo string Repository in "user/repo" format
---@return string
function M.cb(repo)
  return "https://codeberg.org/" .. repo
end

return M
