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

---@return boolean
function M.is_wezterm()
  return vim.env.TERM_PROGRAM == "WezTerm"
end

---@return boolean
function M.is_kitty()
  return vim.env.KITTY_WINDOW_ID ~= nil or vim.env.TERM == "xterm-kitty"
end

---@return boolean
function M.is_wezterm_or_kitty()
  return M.is_wezterm() or M.is_kitty()
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

return M
