-- init: globals must be set BEFORE plugin loads
vim.g["chezmoi#use_tmp_buffer"] = 1
vim.g["chezmoi#source_dir_path"] = vim.uv.os_homedir() .. "/.local/share/chezmoi"

vim.pack.add({ { src = gh("alker0/chezmoi.vim") } })
