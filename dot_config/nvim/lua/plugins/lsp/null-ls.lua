local lspconfig = require("lspconfig")
local null_ls = require("null-ls")
local on_attach = require("plugins.lsp.defaults").on_attach

local M = {}

M.setup = function(opts)
	opts = opts or {}

	null_ls.setup({
		sources = {
			null_ls.builtins.formatting.rubocop.with({
				command = "bundle",
				args = vim.list_extend(
					{ "exec", "rubocop" },
					require("null-ls").builtins.formatting.rubocop._opts.args
				),
			}),
			null_ls.builtins.diagnostics.rubocop.with({
				command = "bundle",
				args = vim.list_extend(
					{ "exec", "rubocop" },
					require("null-ls").builtins.diagnostics.rubocop._opts.args
				),
			}),
			null_ls.builtins.formatting.pg_format,
			null_ls.builtins.formatting.prismaFmt,
		},
	})
end

return M
