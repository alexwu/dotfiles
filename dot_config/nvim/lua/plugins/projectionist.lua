local nmap = vim.keymap.nmap

vim.g.projectionist_heuristics = {
  ["src/*"] = {
    ["*.ts"] = {
      alternate = {
        "{dirname}/{basename}.test.ts",
        "{dirname}/__tests__/{basename}.test.ts",
      },
      type = "source",
    },
    ["*.tsx"] = {
      alternate = {
        "{dirname}/{basename}.test.ts",
        "{dirname}/{basename}.test.tsx",
        "{dirname}/__tests__/{basename}.test.ts",
        "{dirname}/__tests__/{basename}.test.tsx",
      },
      type = "source",
    },
    ["*.test.ts"] = {
      alternate = {
        "{dirname}/{basename}.ts",
        "{dirname}/../{basename}.ts",
      },
      type = "test",
    },
    ["*.test.tsx"] = {
      alternate = {
        "{dirname}/{basename}.tsx",
        "{dirname}/../{basename}.tsx",
      },
      type = "test",
    },
  },
}

-- nmap("<leader>av", [[:AV<cr>]], { silent = true })
-- nmap("<leader>as", [[:AS<cr>]], { silent = true })
-- nmap("<leader>ae", [[:A<cr>]], { silent = true })