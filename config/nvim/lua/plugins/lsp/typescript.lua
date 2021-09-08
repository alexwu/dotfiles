local function on_attach(client, bufnr) end
local filetypes = {"typescript", "typescriptreact"}
local root_dir = "";
return {on_attach = on_attach, filetypes = filetypes, root_dir = root_dir};
