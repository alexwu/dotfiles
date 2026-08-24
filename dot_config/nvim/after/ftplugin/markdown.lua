-- Sourced after every other markdown ftplugin, so this is the last word on
-- buffer-local options. The global `wrap = false` (options.lua) can be flipped
-- back on per-buffer by other ftplugins; pinning it here guarantees no wrap.
vim.opt_local.wrap = false
