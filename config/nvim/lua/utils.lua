local M = {}
local fn = vim.fn

---@param install_path string
---@return boolean
M.install_packer = function(install_path)
  fn.system {
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
  vim.cmd "packadd packer.nvim"
end

---@param install_path string
---@return boolean
M.needs_packer = function(install_path)
  return fn.empty(fn.glob(install_path)) > 0
end

return M
